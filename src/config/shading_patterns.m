function pats = shading_patterns()
%SHADING_PATTERNS Irradiance patterns for the 4 x 4 series-parallel array.
%
%   pats = shading_patterns() returns a struct array. Each element has:
%     id     short name, for example 'P1'
%     name   title for plots
%     G      4 x 4 irradiance matrix [W/m^2]. Row 1 is the top row.
%            Each column is one string of four panels in series.
%     cause  a real situation that gives this pattern
%
%   P0 to P3 are the test patterns: uniform, one row, one column, and one
%   triangle. They use one shade level (300 W/m^2) so that only the
%   geometry changes. R1 to R5 are realistic cases. Each has a shade level
%   that suits its cause.
%
%   Shade levels. A solid object (a building, a water tank, a parapet)
%   blocks the direct beam. The panel then gets only diffuse light, about
%   100 W/m^2 to 200 W/m^2 on a clear day. A tree canopy lets part of the
%   beam through, about 300 W/m^2 to 600 W/m^2. Dust and droppings cut the
%   light less.
%
%   The model has one irradiance per panel. All the bypass-diode groups
%   of a panel (three for the E325P72) get the same irradiance, so they
%   bypass together. A panel with a partial shadow acts approximately like
%   a panel with the irradiance of its most shaded cell, because its cells
%   are in series. A real partial shadow can bypass one group only. The
%   panel-mode models do not show this case. shading_patterns_grp.m has
%   patterns for the _grp models, with one irradiance for each group.

F = 1000;   % Full sun
S = 300;    % Shade level of P1 to P3

pats = struct('id', {}, 'name', {}, 'G', {}, 'cause', {});

pats(end+1) = pat('P0', 'Uniform', F*ones(4), ...
    'Clear sky, no shade. Reference case.');

pats(end+1) = pat('P1', 'Row shading', ...
    [F F F F; F F F F; F F F F; S S S S], ...
    ['The bottom row is shaded. Each string has one shaded panel. ' ...
     'Causes: the row in front at low sun, snow or dust along the lower edge.']);

pats(end+1) = pat('P2', 'Column shading', ...
    [S F F F; S F F F; S F F F; S F F F], ...
    ['One string is shaded along its full length. ' ...
     'Causes: the shadow of a pole, a lightning mast, or a vent pipe along one string.']);

pats(end+1) = pat('P3', 'Triangle shading', ...
    [F F F F; S F F F; S S F F; S S S F], ...
    ['A triangle of six panels at the lower-left corner. The strings have 3, 2, 1, ' ...
     'and 0 shaded panels. Cause: the diagonal edge of a building shadow.']);

pats(end+1) = pat('R1', 'Inter-row shadow, low sun', ...
    [F F F F; F F F F; 600 600 600 600; 150 150 150 150], ...
    ['Winter morning or evening. The row in front puts the bottom row in full ' ...
     'shadow (150) and the next row in partial shadow (600).']);

pats(end+1) = pat('R2', 'Water tank at one corner', ...
    [F F F F; F F F F; 150 150 F F; 150 150 F F], ...
    ['A rooftop water tank or a stair room shades a 2 x 2 block. ' ...
     'Solid object, so only diffuse light (150).']);

pats(end+1) = pat('R3', 'Tree canopy, graded', ...
    [F F F F; 700 F F F; 500 700 F F; 300 500 700 F], ...
    ['A tree at one corner. The canopy is denser near the trunk, so the ' ...
     'shade has three levels.']);

pats(end+1) = pat('R4', 'One soiled panel', ...
    [F F F F; F F F F; F F F F; F F F 600], ...
    'Bird droppings or heavy dust on one panel.');

pats(end+1) = pat('R5', 'Cloud edge over half the array', ...
    [400 400 F F; 400 400 F F; 400 400 F F; 400 400 F F], ...
    ['A cloud covers the two left strings. Each string has one irradiance, ' ...
     'so no bypass diode conducts.']);
end

function s = pat(id, name, G, cause)
s = struct('id', id, 'name', name, 'G', G, 'cause', cause);
end
