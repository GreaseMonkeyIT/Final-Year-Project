function [st, D, fin, gdone] = gmppt_direct(st, p, V, I, globalOnly)
%GMPPT_DIRECT One step of the DIRECT search of Nguyen and Low (2010).
%
%   [st, D, fin, gdone] = gmppt_direct(st, p, V, I, globalOnly) follows
%   the interface of gmppt_search.m. Source: T. L. Nguyen and K.-S. Low,
%   "A global maximum power point tracking scheme employing DIRECT search
%   algorithm for photovoltaic systems," IEEE Trans. Ind. Electron.,
%   vol. 57, no. 10, pp. 3456-3467, 2010. The section, equation and figure
%   numbers below are those of this paper.
%
%   Intervals. Each sample is the center of one interval of the duty
%   axis. A division cuts an interval into three equal parts. The old
%   sample is the center of the middle part. The two new samples are the
%   centers of the outer parts (section III-A). st.lev is the level of an
%   interval. Its length is st.L0 / 3^lev.
%
%   Names. D1 is the center of the sampling interval. D2 is the center of
%   the left third (lower duty, higher voltage). D3 is the center of the
%   right third (higher duty, lower voltage). Dj,2 and Dj,3 are the left
%   and the right child of interval j. This agrees with Figs. 3 and 6.
%
%   Steps:
%     1. Sampling interval (section IV-A). p.dir_range = 0: p.Dlo to
%        p.Dhi. p.dir_range = 1: p.dir_Dlo_abs to p.dir_Dhi_abs, which
%        pv4x4_config calculates from Eqs. (13) to (18).
%     2. First samples: D1, D2, D3 (section IV-B).
%     3. Shading test, Eqs. (19) and (20):
%          (I_D3 - I_D1) / I_D3 >= p.dir_c19   (0.1)
%          (V_D2 - V_D1) / V_D2 >= p.dir_c20   (0.2)
%        Both true: partial shading, go to step 4. Both false: uniform,
%        go to step 6. Only one true: extra samples (section IV-B,
%        Fig. 5a). If (19) is false, the better of D1 and D2 is divided.
%        If (20) is false, the better of D1 and D3 is divided. One new
%        sample then lies between the two old samples. The test is made
%        again on the three samples around it: the old sample at the
%        higher duty takes the place of D3, the new sample takes the place
%        of D1, and the old sample at the lower duty takes the place of D2.
%     4. Globally biased stage (section IV-C). Each cycle divides the
%        potentially optimal interval (Eqs. (11) and (12), with
%        p.dir_eps_g) that has the largest length. The cycles continue
%        until each third is divided or removed by a skip rule. Skip rules:
%          1) V_D3 < p.dir_kVmin * p.dir_Voc: D3,3 is not taken.
%          2) I_D2 < p.dir_kImin * p.dir_Isc, or
%             V_D2 > p.dir_kVmax * p.dir_Voc: D2,2 is not taken.
%          3) (19) is false: the third of D3 is not divided.
%          4) (20) is false: the third of D2 is not divided.
%     5. End of the global stage. If the two samples with the highest
%        powers are neighbours on the duty axis, go to step 6. If not, do
%        two more global cycles, then go to step 6.
%     6. Locally biased stage (section IV-D). Each cycle divides the
%        interval of the sample with the highest power. The search ends
%        when the length of this interval is p.dir_dcr or less (Eq. (21)).
%     7. Hand-over at the duty of the best sample. The paper then holds
%        the point with a P&O of step dcr. The search reports this as
%        st.end_kind = 1 and st.end_step = p.dir_dcr. The controller uses
%        it only if p.paper_end = 1.
%
%   Ties. If two samples have the same power, the sample that was taken
%   first is the better one.
%
%   globalOnly = true (Idea B, gmppt_ideab.m): the function stops where
%   step 5 or step 6 would start their divisions, and returns gdone = true.
%   It then takes no extra global cycles and no local cycles.
%
%   docs/notes/gmppt_methods.md, section 2, gives the reason for each reading of the
%   paper.

fin   = false;
gdone = false;
D     = st.Dp; %#ok<NASGU>
nMax  = numel(st.D);

% First call: sampling interval and the first three probes.
if st.stage == 0
    if p.dir_range == 1
        a = p.dir_Dlo_abs;
        b = p.dir_Dhi_abs;
    else
        a = p.Dlo;
        b = p.Dhi;
    end
    st.a  = a;
    st.L0 = b - a;
    st.qD(1) = a + st.L0 / 2;              % D1
    st.qD(2) = a + st.L0 / 6;              % D2
    st.qD(3) = b - st.L0 / 6;              % D3
    st.qL(1) = 1; st.qL(2) = 1; st.qL(3) = 1;
    st.qn = 3;
    st.qi = 0;
    st.stage = 1;
    [st, D] = nextProbe(st);
    return
end

% Store the sample of the probe that the converter had.
st = gmppt_store_add(st, st.Dp, V, I, st.qL(st.qi));
if st.qi < st.qn
    [st, D] = nextProbe(st);               % The second probe of a division
    return
end

% All the probes of the last division are in the store: one decision.

% Stage 1: shading test on D1, D2, D3 (store entries 1, 2, 3).
if st.stage == 1
    st.c19 = (st.I(3) - st.I(1)) >= p.dir_c19 * st.I(3);
    st.c20 = (st.V(2) - st.V(1)) >= p.dir_c20 * st.V(2);
    if st.c19 && st.c20
        st.stage = 3;                      % Partial shading
    elseif ~st.c19 && ~st.c20
        st.stage = 5;                      % Uniform
    else
        % Only one is true: extra samples (Fig. 5a).
        j = 1;
        if ~st.c19
            if st.P(2) > st.P(1)
                j = 2;
            end
        else
            if st.P(3) > st.P(1)
                j = 3;
            end
        end
        st.jid   = j;
        st.stage = 2;
        st = divide(st, j, false, false);
        [st, D] = nextProbe(st);
        return
    end
end

% Stage 2: shading test again, with the new sample between two old ones.
% Entry 4 is the left child and entry 5 is the right child of st.jid.
if st.stage == 2
    if ~st.c19                             % Region between D1 and D2
        hi = 1;
        lo = 2;
        if st.jid == 1
            m = 4;                         % D1,2
        else
            m = 5;                         % D2,3
        end
    else                                   % Region between D3 and D1
        hi = 3;
        lo = 1;
        if st.jid == 1
            m = 5;                         % D1,3
        else
            m = 4;                         % D3,2
        end
    end
    t19 = (st.I(hi) - st.I(m)) >= p.dir_c19 * st.I(hi);
    t20 = (st.V(lo) - st.V(m)) >= p.dir_c20 * st.V(lo);
    if t19 && t20
        st.stage = 3;
    else
        st.stage = 5;
    end
end

% Stage 3: global cycles until each third is divided or removed.
if st.stage == 3
    open = false;
    for j = 1:3
        if st.lev(j) == 1 && ~isBlocked(st, j)
            open = true;
        end
    end
    if open
        if st.n + 2 > nMax
            [st, D, fin] = finish(st, p);
            return
        end
        j = largestPoi(st, p.dir_eps_g);
        skipL = false;
        skipR = false;
        if j == 3                          % Skip rule 1
            skipR = st.V(3) < p.dir_kVmin * p.dir_Voc;
        elseif j == 2                      % Skip rule 2
            skipL = st.I(2) < p.dir_kImin * p.dir_Isc || ...
                    st.V(2) > p.dir_kVmax * p.dir_Voc;
        end
        st = divide(st, j, skipL, skipR);
        [st, D] = nextProbe(st);
        return
    end
    % End of the global stage: are the two best samples neighbours?
    if twoBestAreNeighbours(st)
        st.stage = 5;
    else
        st.stage = 4;
        st.gx = 0;
    end
    if globalOnly
        gdone = true;
        D = st.D(st.ib);
        return
    end
end

% Stage 4: two more global cycles.
if st.stage == 4
    if st.gx < 2
        if st.n + 2 > nMax
            [st, D, fin] = finish(st, p);
            return
        end
        j = largestPoi(st, p.dir_eps_g);
        st.gx = st.gx + 1;
        st = divide(st, j, false, false);
        [st, D] = nextProbe(st);
        return
    end
    st.stage = 5;
end

% Stage 5: locally biased stage.
if globalOnly
    gdone = true;                          % Uniform case of Idea B
    D = st.D(st.ib);
    return
end
j = st.ib;
if st.L0 / 3^st.lev(j) <= p.dir_dcr || st.n + 2 > nMax
    [st, D, fin] = finish(st, p);          % Eq. (21), or the store is full
    return
end
st = divide(st, j, false, false);
[st, D] = nextProbe(st);
end

function [st, D] = nextProbe(st)
% Apply the next probe that waits.
st.qi = st.qi + 1;
D     = st.qD(st.qi);
st.Dp = D;
st.np = st.np + 1;
end

function st = divide(st, j, skipL, skipR)
% Cut interval j into three parts. The two new centers wait as probes.
% skipL or skipR removes the left or the right child (skip rules 1 and 2).
st.lev(j) = st.lev(j) + 1;
h = st.L0 / 3^st.lev(j);                   % New length, and center distance
st.qn = 0;
st.qi = 0;
if ~skipL
    st.qn = st.qn + 1;
    st.qD(st.qn) = st.D(j) - h;
    st.qL(st.qn) = st.lev(j);
end
if ~skipR
    st.qn = st.qn + 1;
    st.qD(st.qn) = st.D(j) + h;
    st.qL(st.qn) = st.lev(j);
end
end

function [st, D, fin] = finish(st, p)
% End of the search: hand-over at the best sample.
fin = true;
D   = st.D(st.ib);
st.end_kind = 1;                           % The paper holds the point with P&O
st.end_step = p.dir_dcr;
end

function b = isBlocked(st, j)
% Skip rules 3 and 4: a third that the global stage must not divide.
b = (j == 3 && ~st.c19 && st.lev(3) == 1) || ...
    (j == 2 && ~st.c20 && st.lev(2) == 1);
end

function j = largestPoi(st, epsv)
% Potentially optimal interval with the largest length, Eqs. (11), (12).
% If two such intervals have the same length, the higher power wins. Then
% the lower index wins. Blocked thirds are not in the comparison.
j = st.ib;
found = false;
for c = 1:st.n
    if ~isBlocked(st, c) && isPoi(st, c, epsv)
        if ~found || st.lev(c) < st.lev(j) || ...
                (st.lev(c) == st.lev(j) && st.P(c) > st.P(j))
            j = c;
            found = true;
        end
    end
end
end

function ok = isPoi(st, j, epsv)
% Eqs. (11) and (12): is there a K > 0 with
%   P_j + K d_j >= P_i + K d_i for each interval i, and
%   P_j + K d_j >= Pmax + epsv * Pmax ?
% d is half of the length of an interval.
dj  = 0.5 * st.L0 / 3^st.lev(j);
Pj  = st.P(j);
Klo = (st.P(st.ib) * (1 + epsv) - Pj) / dj;        % From Eq. (12)
if Klo < 0
    Klo = 0;
end
Khi = Inf;
ok  = true;
for i = 1:st.n
    if i ~= j && ~isBlocked(st, i)
        if st.lev(i) == st.lev(j)
            if st.P(i) > Pj
                ok = false;                % A better interval of the same length
            end
        else
            di = 0.5 * st.L0 / 3^st.lev(i);
            if di < dj
                Klo = max(Klo, (st.P(i) - Pj) / (dj - di));
            else
                Khi = min(Khi, (Pj - st.P(i)) / (di - dj));
            end
        end
    end
end
ok = ok && Khi > 0 && Klo <= Khi;
end

function nb = twoBestAreNeighbours(st)
% True if the two samples with the highest powers are next to each other
% on the duty axis.
i1 = st.ib;
i2 = 0;
for i = 1:st.n
    if i ~= i1 && (i2 == 0 || st.P(i) > st.P(i2))
        i2 = i;
    end
end
k1 = 0;
k2 = 0;
for k = 1:st.n
    if st.ord(k) == i1
        k1 = k;
    end
    if st.ord(k) == i2
        k2 = k;
    end
end
nb = abs(k1 - k2) == 1;
end
