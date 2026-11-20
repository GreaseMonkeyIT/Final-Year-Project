function r = gmppt_static_run(g, p, rin, nPO)
%GMPPT_STATIC_RUN One global search on a static plant, then P&O.
%
%   r = gmppt_static_run(g, p, rin, nPO) runs gmppt_search.m with the
%   method p.alg on the static curve g (fields V and I, as in
%   results/pv4x4_sweeps.mat). rin(D) gives the input resistance of the
%   converter for a duty D. pv_static_point.m gives the operating point of
%   each probe. After the hand-over, nPO steps of P&O follow, as
%   algos.po_local in archive/2026-11-21_post_midreview/python/algos.py.
%
%   Fields of r:
%     D, V, I   duty and operating point of every probe, search and P&O
%     nSearch   number of search probes
%     Dhand     hand-over duty
%     gmpp      largest power of the curve [W]
%     final     mean power of the last 10 probes / gmpp (algos.summarize)
%
%   gmppt_static_check.m and run_gmppt_group.m use this function.

Dl = zeros(0, 1); Vl = Dl; Il = Dl;
st = gmppt_init(p);
[st, D, fin] = gmppt_search(st, p, 0, 0);
while ~fin
    [v, i] = pv_static_point(g.V, g.I, rin(D));
    Dl(end+1, 1) = D; Vl(end+1, 1) = v; Il(end+1, 1) = i; %#ok<AGROW>
    [st, D, fin] = gmppt_search(st, p, v, i);
end
r.nSearch = numel(Dl);
r.Dhand = D;
sgn = 1;
Pold = -1;
for n = 0:nPO
    if n > 0
        D = D + sgn * p.dD;
    end
    [v, i] = pv_static_point(g.V, g.I, rin(D));
    Dl(end+1, 1) = D; Vl(end+1, 1) = v; Il(end+1, 1) = i; %#ok<AGROW>
    if n > 0 && v * i < Pold
        sgn = -sgn;
    end
    Pold = v * i;
end
r.D = Dl; r.V = Vl; r.I = Il;
r.gmpp  = max(g.V .* g.I);
r.final = mean(Vl(end-9:end) .* Il(end-9:end)) / r.gmpp;
end
