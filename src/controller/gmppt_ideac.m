function [st, D, fin] = gmppt_ideac(st, p, V, I)
%GMPPT_IDEAC One step of Idea C: bisection that the measured ceiling guides.
%
%   [st, D, fin] = gmppt_ideac(st, p, V, I) follows the interface of
%   gmppt_search.m.
%
%   Steps:
%     1. Sample the duties p.Dlo, (p.Dlo + p.Dhi) / 2 and p.Dhi.
%     2. Run the ceiling check of gmppt_ceiling.m. With p.c_corner = 1
%        (the default since 2026-11-21), each open gap is split at its
%        corner duty, as in Idea B. With p.c_corner = 0, it is split at
%        its midpoint.
%     3. Hand-over at the duty of the best sample.
%
%   This method is an implementation of published parts:
%     - The ceiling P <= V1 * I2 between two neighbour samples: Boztepe et
%       al. (IEEE Trans. Ind. Electron. 61(7), 2014) and Wang, Li and Ruan
%       (IEEE Trans. Ind. Electron. 63(1), 2016).
%     - "Split the gap with the highest bound first": Piyavskii (1972)
%       and Shubert (1972), as in LIPO (Li et al., IEEE Access 7, 2019).
%     - Halving with the end samples used again: Chiter (Appl. Math.
%       Comput., 2005), BIRECT (J. Glob. Optim. 71(1), 2018) and HALRECT
%       (J. Glob. Optim. 88(1), 2024).
%     - Binary search in duty for partial shading: Tiong et al. (IEEE
%       CENCON 2017, a conference paper).
%     - The same structure in one dimension: mixed monotonic programming
%       (Matthiesen et al., IEEE Trans. Signal Process. 68, 2020).

fin = false;

% First call: the three start probes wait in st.qD.
if st.stage == 0
    st.qD(1) = p.Dlo;
    st.qD(2) = 0.5 * (p.Dlo + p.Dhi);
    st.qD(3) = p.Dhi;
    st.qn = 3;
    st.qi = 1;
    st.stage = 1;
    D     = st.qD(1);
    st.Dp = D;
    st.np = st.np + 1;
    return
end

st = gmppt_store_add(st, st.Dp, V, I, 0);

% The second and the third start probe.
if st.qi < st.qn
    st.qi = st.qi + 1;
    D     = st.qD(st.qi);
    st.Dp = D;
    st.np = st.np + 1;
    return
end

[st, D, fin] = gmppt_ceiling(st, p, p.c_corner == 1, false);
end
