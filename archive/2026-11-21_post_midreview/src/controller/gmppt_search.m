function [st, D, fin] = gmppt_search(st, p, V, I)
%GMPPT_SEARCH One step of the global search (p.alg = 3 to 8).
%
%   [st, D, fin] = gmppt_search(st, p, V, I) takes the measured averages
%   V and I of the probe that the last call returned, and returns the
%   duty D of the next probe. Start with st = gmppt_init(p). On the first
%   call, V and I are not used. When the search ends, fin is true and D
%   is the hand-over duty for P&O. p.alg selects the method:
%
%   p.alg = 3: DIRECT for GMPPT, a simplified form of Nguyen and Low
%     (2010). It differs from the paper in three steps: if only one
%     shading test holds, it treats the case as uniform. Skip rules 1 and
%     2 mark the whole third dead, and rules 3 and 4 are absent. The local
%     stage stops one trisection earlier than Eq. (21). p.alg = 6 follows
%     the paper.
%     1. Sample the centre of [p.Dlo, p.Dhi], then trisect it. The three
%        samples, in order of duty, are s2 (highest V), s1 and s3.
%     2. Partial-shading test: (I3 - I1) / I3 >= p.psc_i and
%        (V2 - V1) / V2 >= p.psc_v. If it is false, go to step 5.
%     3. Globally biased stage, 3 cycles. Among the live intervals of the
%        largest width, take the one with the highest centre power. Skip
%        rules: mark s3 dead if V < p.skip_lo Voc. Mark s2 dead if
%        I < p.skip_lo Isc or V > p.skip_hi Voc. Else trisect it.
%     4. If the two highest powers are not neighbours in duty, trisect
%        the best interval, then the best of the largest live intervals.
%     5. Locally biased stage: trisect the interval with the highest
%        centre power while its width / 3 >= p.dcr.
%     6. Hand over at the centre of the best interval.
%
%   p.alg = 4: Idea B. DIRECT steps 1 to 5, then the ceiling check of
%     the scan-and-skip literature (Boztepe et al. 2014, Wang et al.
%     2016) on all samples:
%     1. Sort the samples by duty. For each pair of neighbours d1 < d2,
%        the ceiling is U = V1 x I2.
%     2. Keep the gaps with U > (1 + p.eps_b) P_best and d2 - d1 > p.tol_b.
%     3. If no gap is left, hand over at the best sample. Else sample the
%        midpoint of the gap with the highest U, and go to 1.
%
%   p.alg = 5: Idea C. Sample p.Dlo, the middle of the range and p.Dhi.
%     Then do the ceiling check of Idea B on these samples.
%
%   p.alg = 6: DIRECT as written in Nguyen and Low (2010), the baseline
%     for Idea B. Phases 10 to 16. The steps and the values that the paper
%     leaves open are in direct_paper of algos.py. In short:
%     1. Sample s1, s2, s3 as for p.alg = 3. Shading test (19), (20).
%     2. Both hold: shaded. Neither holds: uniform, go to 5. One holds:
%        divide the best third, then test again with the new sample
%        between the pair that the failed test did not cover.
%     3. Global stage up to iteration 4: divide the best of the largest
%        intervals. Skip rules 1 and 2 skip only the outer child of s3 or
%        s2. Rules 3 and 4 (after a failed (19) or (20)) do not divide s3
%        or s2 and use up the iteration.
%     4. If the two best samples are not neighbours: divide the best
%        interval, then the best of the largest intervals.
%     5. Local stage: divide the best interval. Stop after a division
%        whose new spacing is at most p.dcr6, Eq. (21).
%     6. Hand over at the best sample.
%
%   p.alg = 7: PSO after Ishaque et al. (2012), the second baseline.
%     Phase 20. p.pso_n particles start evenly spread over the range, both
%     ends included. One iteration applies every particle once. Then the
%     personal and global bests change, and v = w v + c1 r1 (pbest - x) +
%     c2 r2 (gbest - x), with r1 and r2 from the generator lcg. Stop when
%     every |v| < p.pso_vstop or after p.pso_itmax iterations. Hand over
%     at the global best. Same as pso in algos.py.
%
%   p.alg = 8: Idea B refined (2026-11-08). As p.alg = 4, with three
%     changes: no extra cycles after the neighbour test, no locally biased
%     stage, and the ceiling check splits a gap at the corner duty
%     (cornerDuty) in place of the midpoint. The stop test is the same.
%
%   Why the ceiling holds: d1 < d2 gives V1 >= V2 in the buck-boost, and
%   the array current does not rise with V. So every duty in [d1, d2]
%   gives P <= V1 x I2, if each sample is in steady state.
%
%   The steps are the same as direct(), bsp_bound(), direct_certified(),
%   direct_paper(), pso() and direct_certified_plus() in
%   crosscheck/algos.py.
%   gmppt_static_check.m compares the two. The code uses only fixed-size
%   arrays, so Simulink Coder accepts it.

fin = false;
if st.qk > 0                              % Store the result of the last probe
    st.qv(st.qk) = V;
    st.qi(st.qk) = I;
    st = addSample(st, st.q(st.qk), V, I);
end
if st.qk >= st.qn                         % No probe left in the queue: plan
    [st, fin] = planStep(st, p);
end
if fin
    D = st.Dhand;
else
    st.qk = st.qk + 1;
    D = st.q(st.qk);
    st.np = st.np + 1;
end
end

%% Planning
function [st, fin] = planStep(st, p)
% Use the results of the last queue, then queue the next probes or end
% the search. Phases: 0 start, 1 seed sampled, 2 first trisection done,
% 3 globally biased stage, 4 neighbour test, 5 extra cycle,
% 7 locally biased stage, 8 ceiling check, 9 done.
fin = false;
if st.tP > 0
    st = finishTrisect(st);
end
cap = numel(st.Sd);
need = 2;                                  % Most probes that one plan step queues
if p.alg == 7
    need = p.pso_n;
end
busy = true;
while busy
    if st.ns + need > cap || st.nI + 2 > cap
        % No space for more samples: end with the best sample.
        st.Dhand = bestSample(st);
        st.ph = 9;
    end
    switch st.ph
        case 0
            if p.alg == 7
                % PSO: particles evenly spread over the range, both ends
                % included, with zero velocity. Probe all of them.
                n = p.pso_n;
                for k = 1:n
                    st.px(k) = p.Dlo + (k - 1) * (p.Dhi - p.Dlo) / (n - 1);
                    st.pv(k) = 0;
                    st.pbx(k) = st.px(k);
                    st.pbp(k) = -Inf;
                    st.q(k) = st.px(k);
                end
                st.gx = st.px(1);
                st.gp = -Inf;
                st.pit = 0;
                st.rs = p.pso_seed;
                st.qn = n;
                st.qk = 0;
                st.ph = 20;
                busy = false;
            elseif p.alg == 5
                w = (p.Dhi - p.Dlo) / 2;
                st.q(1) = p.Dlo;
                st.q(2) = p.Dlo + w;
                st.q(3) = p.Dhi;
                st.qn = 3;
                st.ph = 8;
            else
                st.q(1) = p.Dlo + (p.Dhi - p.Dlo) / 2;
                st.qn = 1;
                st.ph = 1;
            end
            st.qk = 0;
            busy = false;
        case 1
            st.nI = 1;
            st.Ilo(1) = p.Dlo;
            st.Ihi(1) = p.Dhi;
            st.Ic(1)  = st.q(1);
            st.Iv(1)  = st.qv(1);
            st.Ii(1)  = st.qi(1);
            st.Ip(1)  = st.qv(1) * st.qi(1);
            st.Idead(1) = false;
            st.Itag(1)  = 0;
            st = startTrisect(st, 1);
            st.ph = 2;
            busy = false;
        case 2
            % s2, s1, s3 in order of duty (s2 has the highest V).
            st.Itag(1) = 2;
            st.Itag(3) = 3;
            psc = ((st.Ii(3) - st.Ii(2)) / st.Ii(3) >= p.psc_i) && ...
                  ((st.Iv(1) - st.Iv(2)) / st.Iv(1) >= p.psc_v);
            if p.alg == 6
                st.ph = 10;
            elseif psc
                st.g = 0;
                st.ph = 3;
            elseif p.alg == 8
                st.ph = 8;
            else
                st.ph = 7;
            end
        case 3
            if st.g >= 3
                st.ph = 4;
            else
                st.g = st.g + 1;
                t = bestOfLargest(st);
                if t == 0
                    st.ph = 4;
                elseif st.Itag(t) == 3 && st.Iv(t) < p.skip_lo * p.Voc_arr
                    st.Idead(t) = true;
                elseif st.Itag(t) == 2 && (st.Ii(t) < p.skip_lo * p.Isc_arr || ...
                                            st.Iv(t) > p.skip_hi * p.Voc_arr)
                    st.Idead(t) = true;
                else
                    st = startTrisect(st, t);
                    busy = false;
                end
            end
        case 4
            if p.alg == 8                  % Idea B refined: no extra cycles
                st.ph = 8;
                continue
            end
            o0 = argmaxP(st, 0);
            o1 = argmaxP(st, o0);
            if abs(o0 - o1) ~= 1
                st = startTrisect(st, o0);
                st.ph = 5;
                busy = false;
            else
                st.ph = 7;
            end
        case 5
            t = bestOfLargest(st);
            st.ph = 7;
            if t > 0
                st = startTrisect(st, t);
                busy = false;
            end
        case 7
            t = argmaxP(st, 0);
            if (st.Ihi(t) - st.Ilo(t)) / 3 < p.dcr
                if p.alg == 4
                    st.ph = 8;
                else
                    st.Dhand = st.Ic(t);
                    st.ph = 9;
                end
            else
                st = startTrisect(st, t);
                busy = false;
            end
        case 8
            k = worstGap(st, p);
            if k == 0
                st.Dhand = bestSample(st);
                st.ph = 9;
            else
                if p.alg == 8
                    st.q(1) = cornerDuty(st, k, p.theta_c);
                else
                    st.q(1) = 0.5 * (st.Sd(k) + st.Sd(k+1));
                end
                st.qn = 1;
                st.qk = 0;
                busy = false;
            end
        case 20
            % PSO: one iteration is done. Update the bests, then the
            % velocities, then the positions (algos.pso).
            n = p.pso_n;
            for k = 1:n
                Pk = st.qv(k) * st.qi(k);
                if Pk > st.pbp(k)
                    st.pbp(k) = Pk;
                    st.pbx(k) = st.px(k);
                end
            end
            for k = 1:n
                if st.pbp(k) > st.gp
                    st.gp = st.pbp(k);
                    st.gx = st.pbx(k);
                end
            end
            vmax = 0;
            for k = 1:n
                [st.rs, r1] = lcg(st.rs);
                [st.rs, r2] = lcg(st.rs);
                st.pv(k) = p.pso_w * st.pv(k) + p.pso_c1 * r1 * (st.pbx(k) - st.px(k)) + ...
                           p.pso_c2 * r2 * (st.gx - st.px(k));
                vmax = max(vmax, abs(st.pv(k)));
            end
            st.pit = st.pit + 1;
            if vmax < p.pso_vstop || st.pit >= p.pso_itmax
                st.Dhand = st.gx;
                st.ph = 9;
            else
                for k = 1:n
                    st.px(k) = min(max(st.px(k) + st.pv(k), p.Dlo), p.Dhi);
                    st.q(k) = st.px(k);
                end
                st.qn = n;
                st.qk = 0;
                busy = false;
            end
        case 10
            % DIRECT as in the paper (p.alg = 6): shading test (19), (20).
            st.c19 = (st.Ii(3) - st.Ii(2)) / st.Ii(3) >= p.psc_i;
            st.c20 = (st.Iv(1) - st.Iv(2)) / st.Iv(1) >= p.psc_v;
            st.g = 1;
            if st.c19 && st.c20
                st.ph = 11;
            elseif ~st.c19 && ~st.c20
                st.ph = 13;
            else
                % One condition holds: divide the best third (iteration 2),
                % then test again with the pair that the failed condition
                % did not cover: (s2, s1) if (19) failed, (s1, s3) if (20).
                if ~st.c19
                    hi = 1; lo = 2;
                else
                    hi = 2; lo = 3;
                end
                st.pa = st.Ic(hi);  st.pVhi = st.Iv(hi);
                st.pb = st.Ic(lo);  st.pIlo = st.Ii(lo);
                t = argmaxP(st, 0);
                st = startTrisectSkip(st, p, t);
                st.g = 2;
                st.ph = 12;
                busy = false;
            end
        case 12
            % Test again with the new sample between the pair.
            shaded = false;
            for k = 1:st.nI
                if ~st.Idead(k) && st.Ic(k) > st.pa && st.Ic(k) < st.pb
                    shaded = ((st.pIlo - st.Ii(k)) / st.pIlo >= p.psc_i) && ...
                             ((st.pVhi - st.Iv(k)) / st.pVhi >= p.psc_v);
                    break
                end
            end
            if shaded
                % Skip rule 3 ((19) failed) or 4 ((20) failed): do not
                % divide that third. Itag 4 marks it.
                tg = 2;
                if ~st.c19
                    tg = 3;
                end
                for k = 1:st.nI
                    if st.Itag(k) == tg
                        st.Itag(k) = 4;
                    end
                end
                st.ph = 11;
            else
                st.ph = 13;
            end
        case 11
            % Global stage up to iteration 4.
            if st.g >= 4
                st.ph = 14;
            else
                st.g = st.g + 1;
                t = bestOfLargest(st);
                if t == 0
                    st.ph = 14;
                elseif st.Itag(t) == 4
                    st.Idead(t) = true;    % Rule 3 or 4 uses the iteration
                else
                    st = startTrisectSkip(st, p, t);
                    busy = false;
                end
            end
        case 14
            % Two best samples not neighbours: iterations 5 and 6.
            o0 = argmaxP(st, 0);
            o1 = argmaxP(st, o0);
            st.ph = 13;
            if ~neighbours(st, o0, o1)
                t = 0;
                for k = 1:st.nI
                    if ~st.Idead(k) && (t == 0 || st.Ip(k) > st.Ip(t))
                        t = k;
                    end
                end
                if t > 0
                    st = startTrisectSkip(st, p, t);
                    st.ph = 15;
                    busy = false;
                end
            end
        case 15
            t = bestOfLargest(st);
            st.ph = 13;
            if t > 0
                st = startTrisectSkip(st, p, t);
                busy = false;
            end
        case 13
            % Local stage: divide the best interval. Stop after a division
            % whose new spacing (width / 3) is at most p.dcr6, Eq. (21).
            t = argmaxP(st, 0);
            st.lastW = (st.Ihi(t) - st.Ilo(t)) / 3;
            st = startTrisect(st, t);
            st.ph = 16;
            busy = false;
        case 16
            if st.lastW <= p.dcr6
                st.Dhand = st.Ic(argmaxP(st, 0));
                st.ph = 9;
            else
                st.ph = 13;
            end
        otherwise
            fin = true;
            busy = false;
    end
end
end

%% DIRECT intervals
function st = startTrisect(st, t)
% Queue the centres of the outer thirds of interval t.
w = (st.Ihi(t) - st.Ilo(t)) / 3;
st.q(1) = st.Ilo(t) + w / 2;
st.q(2) = (st.Ilo(t) + 2 * w) + w / 2;
st.qn = 2;
st.qk = 0;
st.tP = t;
st.tW = w;
st.tSkL = false;
st.tSkR = false;
end

function st = startTrisectSkip(st, p, t)
% As startTrisect, with the skip rules 1 and 2 of Nguyen and Low (2010,
% p. 3461) for p.alg = 6. Rule 1: if V(s3) < Voc / 3, do not sample the
% low-voltage child of s3. Rule 2: if I(s2) < Isc / 3 or V(s2) > 0.9 Voc,
% do not sample the high-voltage child of s2.
st = startTrisect(st, t);
if st.Itag(t) == 3 && st.Iv(t) < p.skip_lo * p.Voc_arr
    st.tSkR = true;
    st.qn = 1;
elseif st.Itag(t) == 2 && (st.Ii(t) < p.skip_lo * p.Isc_arr || ...
                            st.Iv(t) > p.skip_hi * p.Voc_arr)
    st.tSkL = true;
    st.q(1) = st.q(2);
    st.qn = 1;
end
end

function st = finishTrisect(st)
% Replace interval t by its three thirds. The middle third keeps the
% centre sample of t. The order of rising duty does not change.
t  = st.tP;
w  = st.tW;
lo = st.Ilo(t);
for k = st.nI:-1:t+1                       % Move the intervals after t by two places
    st = moveInterval(st, k, k + 2);
end
st = moveInterval(st, t, t + 1);           % Middle third
st.Ilo(t+1) = lo + w;
st.Ihi(t+1) = lo + 2 * w;
st.Idead(t+1) = false;
st.Itag(t+1)  = 0;
if st.tSkL                                 % Skip rule 2: no sample
    st = setSkipped(st, t, lo, lo + w);
    st = setInterval(st, t + 2, lo + 2 * w, (lo + 2 * w) + w, 1);
elseif st.tSkR                             % Skip rule 1: no sample
    st = setInterval(st, t, lo, lo + w, 1);
    st = setSkipped(st, t + 2, lo + 2 * w, (lo + 2 * w) + w);
else
    st = setInterval(st, t, lo, lo + w, 1);
    st = setInterval(st, t + 2, lo + 2 * w, (lo + 2 * w) + w, 2);
end
st.nI = st.nI + 2;
st.tP = 0;
st.tSkL = false;
st.tSkR = false;
end

function st = setSkipped(st, k, lo, hi)
% Interval k from lo to hi with no sample. It is dead and never chosen.
st.Ilo(k) = lo;
st.Ihi(k) = hi;
st.Ic(k)  = lo + (hi - lo) / 2;
st.Iv(k)  = 0;
st.Ii(k)  = 0;
st.Ip(k)  = -1;
st.Idead(k) = true;
st.Itag(k)  = 0;
end

function ok = neighbours(st, a, b)
% True if no sampled interval lies between intervals a and b.
ok = true;
for k = min(a, b) + 1:max(a, b) - 1
    if st.Ip(k) >= 0
        ok = false;
    end
end
end

function st = moveInterval(st, a, b)
st.Ilo(b) = st.Ilo(a); st.Ihi(b) = st.Ihi(a); st.Ic(b) = st.Ic(a);
st.Iv(b)  = st.Iv(a);  st.Ii(b)  = st.Ii(a);  st.Ip(b) = st.Ip(a);
st.Idead(b) = st.Idead(a);
st.Itag(b)  = st.Itag(a);
end

function st = setInterval(st, k, lo, hi, j)
% Interval k from lo to hi, with the sample of queue entry j at its centre.
st.Ilo(k) = lo;
st.Ihi(k) = hi;
st.Ic(k)  = st.q(j);
st.Iv(k)  = st.qv(j);
st.Ii(k)  = st.qi(j);
st.Ip(k)  = st.qv(j) * st.qi(j);
st.Idead(k) = false;
st.Itag(k)  = 0;
end

function t = argmaxP(st, skip)
% First interval with the highest centre power, without interval skip.
t = 0;
for k = 1:st.nI
    if k ~= skip && (t == 0 || st.Ip(k) > st.Ip(t))
        t = k;
    end
end
end

function t = bestOfLargest(st)
% Among the live intervals of the largest width, the first one with the
% highest centre power. 0 if no interval is live.
big = -1;
for k = 1:st.nI
    if ~st.Idead(k)
        big = max(big, st.Ihi(k) - st.Ilo(k));
    end
end
t = 0;
for k = 1:st.nI
    if ~st.Idead(k) && abs((st.Ihi(k) - st.Ilo(k)) - big) < 1e-12 && ...
            (t == 0 || st.Ip(k) > st.Ip(t))
        t = k;
    end
end
end

%% Samples and the ceiling check
function st = addSample(st, d, V, I)
% Insert one sample. The samples stay in order of rising duty.
k = st.ns;
while k >= 1 && st.Sd(k) > d
    st.Sd(k+1) = st.Sd(k);
    st.Sv(k+1) = st.Sv(k);
    st.Si(k+1) = st.Si(k);
    k = k - 1;
end
st.Sd(k+1) = d;
st.Sv(k+1) = V;
st.Si(k+1) = I;
st.ns = st.ns + 1;
end

function d = bestSample(st)
% Duty of the first sample with the highest power.
d = st.Sd(1);
Pb = -1;
for k = 1:st.ns
    if st.Sv(k) * st.Si(k) > Pb
        Pb = st.Sv(k) * st.Si(k);
        d = st.Sd(k);
    end
end
end

function [s, r] = lcg(s)
% 32-bit linear congruential generator (Numerical Recipes constants), the
% same as lcg in algos.py. All products stay below 2^53, so the double
% arithmetic is exact and Python and MATLAB draw the same numbers.
s = mod(1664525 * s + 1013904223, 4294967296);
r = s / 4294967296;
end

function d = cornerDuty(st, k, theta)
% Duty in the gap between samples k and k + 1 where R = V / I equals
% V1 / I2 (the corner of the box that holds every point of the gap). The
% ideal buck-boost has ln R = ln R_load + 2 x with x = ln((1 - d) / d),
% so the duty comes from a linear interpolation of the two measured ln R
% in x. No converter value is needed. The duty stays at least theta times
% the gap width from each end. Same as corner_duty in algos.py.
d1 = st.Sd(k);   d2 = st.Sd(k+1);
v1 = st.Sv(k);   i1 = max(st.Si(k), 1e-9);
v2 = st.Sv(k+1); i2 = max(st.Si(k+1), 1e-9);
w  = d2 - d1;
if v1 <= 0 || v2 <= 0                      % No resistance to interpolate
    d = min(max(0.5 * (d1 + d2), d1 + theta * w), d2 - theta * w);
    return
end
x1 = log((1 - d1) / d1);
x2 = log((1 - d2) / d2);
y1 = log(v1 / i1);
y2 = log(v2 / i2);
if abs(y1 - y2) < 1e-12
    d = 0.5 * (d1 + d2);
else
    x = x1 + (log(v1 / i2) - y1) * (x2 - x1) / (y2 - y1);
    d = 1 / (1 + exp(x));
end
d = min(max(d, d1 + theta * w), d2 - theta * w);
end

function g = worstGap(st, p)
% Gap k (between samples k and k + 1) with the highest ceiling V1 x I2
% that can still beat the best power. 0 if there is none. For equal
% ceilings, the gap with the higher duty wins, as in algos.py.
Pb = -1;
for k = 1:st.ns
    Pb = max(Pb, st.Sv(k) * st.Si(k));
end
g = 0;
Ub = -1;
for k = 1:st.ns - 1
    U = st.Sv(k) * st.Si(k+1);
    if U > Pb * (1 + p.eps_b) && st.Sd(k+1) - st.Sd(k) > p.tol_b && U >= Ub
        Ub = U;
        g = k;
    end
end
if p.alg == 8 && g > 0
    % The corner split gives two new gaps with equal ceilings. Ceilings
    % within a relative 1e-9 count as equal, and the gap with the higher
    % duty wins, as in algos.py.
    for k = 1:st.ns - 1
        U = st.Sv(k) * st.Si(k+1);
        if U > Pb * (1 + p.eps_b) && st.Sd(k+1) - st.Sd(k) > p.tol_b && U >= Ub * (1 - 1e-9)
            g = k;
        end
    end
end
end
