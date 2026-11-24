function [st, D, fin] = gmppt_gwo(st, p, V, I)
%GMPPT_GWO One step of the grey wolf optimization search of Mohanty et al. (2016).
%
%   [st, D, fin] = gmppt_gwo(st, p, V, I) follows the interface of
%   gmppt_search.m. Sources:
%     [M16] S. Mohanty, B. Subudhi and P. K. Ray, "A new MPPT design using
%           grey wolf optimization technique for photovoltaic system under
%           partial shading conditions," IEEE Trans. Sustain. Energy,
%           vol. 7, no. 1, pp. 181-188, 2016.
%     [G14] S. Mirjalili, S. M. Mirjalili and A. Lewis, "Grey wolf
%           optimizer," Adv. Eng. Softw., vol. 69, pp. 46-61, 2014, and
%           the GWO.m code of its first author.
%
%   The position of a wolf is a duty [M16, section III-B]. The power of
%   the array is the fitness. One probe measures one wolf. One iteration
%   measures all the wolves in turn [M16, Fig. 5].
%
%   [M16] gives the encircling equations (2) to (6) and the flowchart. It
%   does not give the number of wolves, the start duties, the number of
%   iterations or the end test, and it prints the update with one leader.
%   This file uses the update with three leaders of [G14], which [M16]
%   names as its source. docs/notes/gmppt_methods.md, section 6, lists each choice.
%
%   Steps:
%     1. Start. The wolves start at the duties p.gwo_D0.
%     2. After each iteration, the three best points found so far are
%        the alpha, beta and delta wolves [M16, section III-A].
%     3. a = 2 - 2 l / p.gwo_itmax, with l = 0 in the first iteration, so
%        that a goes down from 2 in equal steps [M16, section IV-A; G14].
%     4. New position of each wolf. For each leader L (alpha, beta,
%        delta), with two new random numbers r1 and r2 in (0, 1):
%          A = 2 a r1 - a                    [M16, Eq. (4)]
%          C = 2 r2                          [M16, Eq. (5)]
%          dist = |C D_L - D_wolf|           [G14]
%          X_L = D_L - A dist                [M16, Eq. (3)]
%        The new duty is the mean of the three X_L [G14]. It stays in
%        [p.Dlo, p.Dhi].
%     5. End. The search ends after p.gwo_itmax iterations, or when each
%        wolf is not more than p.gwo_tol from the alpha wolf, or when the
%        store has no space for one more iteration. The hand-over duty is
%        that of the alpha wolf. [M16] then holds this duty, so the
%        search reports st.end_kind = 2. The controller uses it only if
%        p.paper_end = 1.
%
%   The store (st.D, st.V, st.I, st.P) keeps each probe for the record.
%   The search does not read it.

fin = false;
Nw  = numel(st.wx);

% First call: start positions.
if st.stage == 0
    % st.rng comes from gmppt_init.m or from the last search (restart).
    for i = 1:Nw
        st.wx(i) = min(max(p.gwo_D0(i), p.Dlo), p.Dhi);
    end
    for j = 1:3
        st.lD(j) = st.wx(1);
        st.lP(j) = -1;                     % Below each possible power: not set
    end
    st.it    = 0;
    st.ip    = 1;
    st.stage = 1;
    D     = st.wx(1);
    st.Dp = D;
    st.np = st.np + 1;
    return
end

% Power of the wolf that the converter had.
i = st.ip;
st.wfit(i) = V * I;
st = gmppt_store_add(st, st.Dp, V, I, 0);
if i < Nw
    st.ip = i + 1;                         % Next wolf of this iteration
    D     = st.wx(st.ip);
    st.Dp = D;
    st.np = st.np + 1;
    return
end

% All the wolves are measured: end of one iteration.

% Alpha, beta and delta: the three best points so far, in rank order.
for i = 1:Nw
    Pi = st.wfit(i);
    Di = st.wx(i);
    if Pi > st.lP(1)
        st.lD(3) = st.lD(2); st.lP(3) = st.lP(2);
        st.lD(2) = st.lD(1); st.lP(2) = st.lP(1);
        st.lD(1) = Di;       st.lP(1) = Pi;
    elseif Pi > st.lP(2)
        st.lD(3) = st.lD(2); st.lP(3) = st.lP(2);
        st.lD(2) = Di;       st.lP(2) = Pi;
    elseif Pi > st.lP(3)
        st.lD(3) = Di;       st.lP(3) = Pi;
    end
end

% New positions.
a = 2 - st.it * (2 / p.gwo_itmax);
st.it = st.it + 1;
conv = true;
for i = 1:Nw
    xs = 0;
    for j = 1:3
        [st.rng, r1] = gmppt_rand(st.rng);
        [st.rng, r2] = gmppt_rand(st.rng);
        A    = 2 * a * r1 - a;
        C    = 2 * r2;
        dist = abs(C * st.lD(j) - st.wx(i));
        xs   = xs + (st.lD(j) - A * dist);
    end
    st.wx(i) = min(max(xs / 3, p.Dlo), p.Dhi);
    if abs(st.wx(i) - st.lD(1)) > p.gwo_tol
        conv = false;
    end
end

if conv || st.it >= p.gwo_itmax || st.n + Nw > numel(st.D)
    fin = true;
    D   = st.lD(1);
    st.end_kind = 2;                       % The paper holds the duty
    st.end_step = 0;
    return
end

st.ip = 1;                                 % First wolf of the next iteration
D     = st.wx(1);
st.Dp = D;
st.np = st.np + 1;
end
