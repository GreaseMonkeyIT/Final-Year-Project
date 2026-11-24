function [st, D, fin] = gmppt_ceiling(st, p, corner)
%GMPPT_CEILING One step of the ceiling check on the sample store.
%
%   [st, D, fin] = gmppt_ceiling(st, p, corner) reads all the samples of
%   the store and makes one decision. If fin is false, D is the duty of
%   the next probe. If fin is true, the check is complete and D is the
%   duty of the best sample. The caller adds each new sample to the store
%   (gmppt_store_add.m) before the next call. Idea B (gmppt_ideab.m) and
%   Idea C (gmppt_ideac.m) use this function.
%
%   The measured ceiling. Two neighbour samples have the duties d1 < d2
%   and the measured points (V1, I1) and (V2, I2). A higher duty gives a
%   lower voltage, so V1 >= V2. The array current does not rise when the
%   voltage rises. Then each duty d in [d1, d2] gives
%       P(d) = V(d) * I(d) <= V1 * I2 = U.
%   Sources of the inequality: Boztepe et al., IEEE Trans. Ind. Electron.
%   61(7), 2014, and Wang, Li and Ruan, IEEE Trans. Ind. Electron. 63(1),
%   2016. It holds for samples in steady state on a curve that does not
%   change during the search.
%
%   The check:
%     1. P_best is the highest sampled power.
%     2. A gap between two neighbours is open if
%        U (1 + p.delta_s)^2 > (1 + p.eps_c) P_best (1 - 2 p.delta_s)
%        and d2 - d1 > p.tau. p.delta_s is a bound for the relative
%        sensor error. With p.delta_s = 0 the test is U > (1 + eps_c) P_best.
%     3. If no gap is open, or the store is full, the check ends.
%     4. Else the check splits the open gap with the highest U. If two
%        ceilings agree to a relative difference of 1e-9, the gap at the
%        higher duty is split.
%   The rule "split the gap with the highest bound first" is the rule of
%   Piyavskii (1972) and Shubert (1972), as LIPO uses it for GMPPT (Li et
%   al., IEEE Access 7, 2019).
%
%   Split duty. corner = false: the midpoint of the gap. corner = true:
%   the corner duty. The corner (V1, I2) of the gap lies on the load line
%   R* = V1 / I2. For the ideal buck-boost, ln R = ln R_load + 2 x with
%   x = ln((1 - D) / D). The function draws a straight line through the
%   two measured points (x, ln(V / I)) at the ends of the gap and solves
%   it for ln R*. This needs no converter value. The result is clamped to
%   [d1 + p.theta w, d2 - p.theta w], with w = d2 - d1. The corner split
%   is the projection step of the polyblock algorithm of monotonic
%   optimization (Tuy, SIAM J. Optim. 11(2), 2000; Zhang, Qian and Huang,
%   Found. Trends Netw. 7(1), 2012, section 3.2).
%
%   Certificate. At each call the function writes
%     st.cert     largest U of the gaps that do not touch the best sample,
%                 divided by P_best
%     st.certAll  largest U of all the gaps, divided by P_best
%   The gaps cover only the duties from the lowest sample to the highest
%   sample. The check gives no bound outside this range.

fin = false;
ib  = st.ib;
Pb  = st.P(ib);
D   = st.D(ib);

gain = (1 + p.delta_s)^2;
lim  = (1 + p.eps_c) * Pb * (1 - 2 * p.delta_s);

kb = 0;                                    % Place of the gap to split, 0 = none
Ub = 0;                                    % Its ceiling
Uc = 0;                                    % Largest ceiling away from the best sample
Ua = 0;                                    % Largest ceiling of all the gaps
for k = 1:st.n-1
    i1 = st.ord(k);                        % Lower duty, higher voltage
    i2 = st.ord(k+1);                      % Higher duty, higher current
    U  = st.V(i1) * st.I(i2);
    if U > Ua
        Ua = U;
    end
    if i1 ~= ib && i2 ~= ib && U > Uc
        Uc = U;
    end
    if U * gain > lim && st.D(i2) - st.D(i1) > p.tau
        % The loop goes up in duty. On a tie, the later gap replaces the
        % earlier one, so the gap at the higher duty is split.
        if kb == 0 || U > Ub || abs(U - Ub) <= 1e-9 * max(U, Ub)
            kb = k;
            Ub = max(U, Ub);
        end
    end
end
if Pb > 0
    st.cert    = Uc / Pb;
    st.certAll = Ua / Pb;
else
    st.cert    = 0;
    st.certAll = 0;
end

if kb == 0 || st.n >= numel(st.D)
    fin = true;                            % No open gap, or the store is full
    return
end

i1 = st.ord(kb);
i2 = st.ord(kb+1);
d1 = st.D(i1);
d2 = st.D(i2);
D  = 0.5 * (d1 + d2);
if corner
    D = cornerDuty(d1, st.V(i1), st.I(i1), d2, st.V(i2), st.I(i2), D, p.theta);
end
st.Dp = D;
st.np = st.np + 1;
end

function d = cornerDuty(d1, V1, I1, d2, V2, I2, dmid, theta)
% Duty whose load line goes through the corner (V1, I2) of the gap.
d = dmid;
if V1 > 0 && I1 > 0 && V2 > 0 && I2 > 0
    x1 = log((1 - d1) / d1);
    x2 = log((1 - d2) / d2);
    y1 = log(V1 / I1);                     % ln R at the low-duty end
    y2 = log(V2 / I2);                     % ln R at the high-duty end
    ys = log(V1 / I2);                     % ln R* of the corner
    if abs(y2 - y1) > 1e-12
        xs = x1 + (ys - y1) * (x2 - x1) / (y2 - y1);
        d  = 1 / (1 + exp(xs));
    end
end
w = d2 - d1;
d = min(max(d, d1 + theta * w), d2 - theta * w);
end
