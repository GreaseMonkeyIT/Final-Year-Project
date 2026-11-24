function p = final_variant(p, v)
%FINAL_VARIANT Controller values of one variant of the final tests.
%
%   p = final_variant(p, v) sets p.alg and the ending of the search in the
%   mppt struct p (cfg.mppt of pv4x4_config.m) for the variant v (fields
%   alg and loc). final_vname.m gives the name of the variant.
%     alg   1 P&O, 2 INC (from start-up, no search), 3 DIRECT, 4 Idea B,
%           5 Idea C, 6 PSO, 7 GWO
%     loc   0      no search (alg 1, 2)
%           1 to 4 local stage after the search (p.local): 1 P&O,
%                  2 VS-INC, 3 parabolic, 4 INC
%           5      the ending of the paper of the search (p.paper_end = 1).
%                  DIRECT: the P&O of step p.dir_dcr (Nguyen and Low 2010).
%
%   Added on 2026-11-23. The final comparison (choice of the user) is Idea C
%   with the parabolic stage against DIRECT as in its paper, Idea B, PSO
%   and GWO with the parabolic stage, and P&O and INC from start-up.
%   final_variants.m gives this list.

alg = v.alg; loc = v.loc;
p.alg = alg;
p.paper_end = 0;
if loc >= 1 && loc <= 4
    p.local = loc * ones(size(p.local));
elseif loc == 5
    p.paper_end = 1;
end
end
