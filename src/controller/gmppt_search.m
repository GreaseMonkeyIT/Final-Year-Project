function [st, D, fin] = gmppt_search(st, p, V, I)
%GMPPT_SEARCH One step of the global search that p.alg selects.
%
%   [st, D, fin] = gmppt_search(st, p, V, I) is called by mppt_controller.m
%   for p.alg = 3 to 8:
%     - once at the start of a search, with V = 0 and I = 0. The returned
%       D is the first probe duty. The controller ignores fin on this call.
%     - at the end of each search probe, with the averages V and I of that
%       probe. If fin is false, D is the next probe duty. If fin is true,
%       the search ends and the local stage starts at the hand-over duty D.
%   Each probe lasts p.Tsearch and the controller averages the last
%   p.Navg_s samples of it. st comes from gmppt_init.m. st.np counts the
%   probes that the search applied.
%
%   Methods:
%     p.alg = 3  DIRECT of Nguyen and Low (2010)               gmppt_direct.m
%     p.alg = 4  Idea B refined: DIRECT global stage, then the
%                ceiling check with the corner split           gmppt_ideab.m
%     p.alg = 5  Idea C: bisection that the ceiling guides     gmppt_ideac.m
%     p.alg = 6  PSO of Ishaque et al. (2012)                  gmppt_pso.m
%     p.alg = 7  GWO of Mohanty et al. (2016)                  gmppt_gwo.m
%     p.alg = 8  not used. The search ends at once at p.Dstart.
%   Each method is an implementation of a published method or of
%   published parts. Each file names its sources. docs/notes/gmppt_methods.md gives
%   the full description.
%
%   The returned duty is always in [p.Dmin, p.Dmax].

switch p.alg
    case 3
        [st, D, fin] = gmppt_direct(st, p, V, I, false);
    case 4
        [st, D, fin] = gmppt_ideab(st, p, V, I);
    case 5
        [st, D, fin] = gmppt_ideac(st, p, V, I);
    case 6
        [st, D, fin] = gmppt_pso(st, p, V, I);
    case 7
        [st, D, fin] = gmppt_gwo(st, p, V, I);
    otherwise
        D   = p.Dstart;
        fin = true;
end
D = min(max(D, p.Dmin), p.Dmax);
end
