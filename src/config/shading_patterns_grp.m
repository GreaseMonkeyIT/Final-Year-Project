function pats = shading_patterns_grp()
%SHADING_PATTERNS_GRP Irradiance patterns of single bypass-diode groups for the 4 x 4 array.
%
%   pats = shading_patterns_grp() returns a struct array with the same
%   fields as shading_patterns.m (id, name, G, cause). Here G is a 12 x 4
%   matrix: one irradiance [W/m^2] for each group of 24 cells. Row
%   (r-1)*3 + g is group g of the panel in row r, so row 1 is the top
%   group of the top panel. Each column is one string.
%
%   A real shadow does not follow the panel edges, so it can cover one
%   group of a panel alone. The string then has more current steps, and the
%   P-V curve has more peaks than with one irradiance for each panel.
%   MPPT_4x4_grp.slx and PV4x4_sweep_grp.slx take these patterns
%   (scripts/build_mppt_4x4.m and scripts/build_pv4x4_sweep.m with the
%   argument true).
%
%   G1 and G2 come from the random group-level and shadow-edge sets of
%   archive/2026-11-21_post_midreview/python/runrand.py, rounded to 50 W/m^2. They are cases where the
%   static cross-check finds that DIRECT and the 0.8 Voc method (M1) miss
%   the global peak. G3 is a diagonal shadow edge.

F = 1000;
pats = struct('id', {}, 'name', {}, 'G', {}, 'cause', {});

% Columns: strings 1 to 4. Rows: groups, top to bottom.
G1 = [F    F    F    F    F    700  F    250  F    650  450  700
      450  450  F    F    800  750  F    F    100  F    F    F
      F    600  F    650  100  F    F    F    F    F    F    F
      F    250  F    F    450  F    300  250  F    F    350  F]';
pats(end+1) = pat('G1', 'Spots on single groups', G1, ...
    ['Leaves, bird droppings and dust on 18 of the 48 groups, at 100 to 800 W/m^2. ' ...
     'The curve has 7 peaks.']);

G2 = [F F F F F F F 250 100 100 100 100
      F F F F F F F F   F   F   F   650
      F F F F F F F F   500 500 500 500
      F F F F F F F F   F   F   750 600]';
pats(end+1) = pat('G2', 'Shadow edge with a soft border', G2, ...
    ['A parapet or a railing shades the lower groups of each string by a different ' ...
     'amount. The border groups get part of the beam.']);

G3 = [F F 600 200 200 200 200 200 200 200 200 200
      F F F   F   F   600 200 200 200 200 200 200
      F F F   F   F   F   F   F   600 200 200 200
      F F F   F   F   F   F   F   F   F   F   F]';
pats(end+1) = pat('G3', 'Diagonal shadow edge', G3, ...
    ['The diagonal edge of a building shadow crosses the panels. Strings 1 to 3 have ' ...
     '9, 6 and 3 groups in full shadow (200) and one group at the edge (600).']);
end

function s = pat(id, name, G, cause)
s = struct('id', id, 'name', name, 'G', G, 'cause', cause);
end
