function [st, D, fin] = gmppt_search(st, p, V, I) %#ok<INUSD>
%GMPPT_SEARCH One step of the global search. PLACEHOLDER: no search.
%
%   [st, D, fin] = gmppt_search(st, p, V, I) is called by mppt_controller.m
%   for p.alg = 3 to 8:
%     - once at the start of a search, with V = 0 and I = 0. The returned
%       D is the first probe duty. The controller ignores fin on this call.
%     - at the end of each search probe, with the averages V and I of that
%       probe. If fin is false, D is the next probe duty. If fin is true,
%       the search ends and P&O starts at the hand-over duty D.
%   Each probe lasts p.Tsearch and the controller averages the last
%   p.Navg_s samples of it. The search range is p.Dlo to p.Dhi.
%
%   This file is a placeholder. It ends the search at once and hands over
%   at p.Dstart, so p.alg = 3 to 8 gives one probe at p.Dstart and then
%   P&O. The global searches of the preliminary study are archived in
%   archive/2026-11-21_post_midreview/src/controller/.
%
%   Do not use the placeholder for P&O runs (use p.alg = 1). The restart
%   rule of mppt_controller.m takes P_ref at the hand-over duty. Here that
%   is p.Dstart, near Voc, where the power is low. The P&O climb then
%   changes the power by more than p.dP_restart, so the controller starts
%   a new search and returns to p.Dstart again and again (checked on
%   2026-11-21: P1 ends at 602 W, against 1796 W for p.alg = 1). A real
%   search hands over near a peak and does not show this.
%
%   Interface rules for a replacement:
%     - Keep the signature. Keep st fixed-size (see gmppt_init.m).
%     - Increase st.np by one for each probe that the search applies.

D = p.Dstart;
fin = true;
end
