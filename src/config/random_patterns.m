function R = random_patterns(nEach, seed)
%RANDOM_PATTERNS Random shading patterns of the 4 x 4 array, for the static tests.
%
%   R = random_patterns(nEach, seed) returns 3*nEach patterns as a struct
%   array with the fields kind ('panel', 'edge' or 'group'), k (number in
%   its kind) and G (12 x 4, one irradiance [W/m^2] for each bypass-diode
%   group, as shading_patterns_grp.m). Defaults: nEach = 300, seed = 1.
%
%   The rules are those of the preliminary study (archive/
%   2026-11-21_post_midreview/python/runrand.py, function gen). The
%   MATLAB generator gives other numbers than the NumPy generator, so the
%   patterns are a new sample of the same three sets:
%     panel  each panel is shaded with probability 0.4, at 100 to
%            900 W/m^2 (uniform). All the groups of a panel are the same.
%     edge   a shadow edge rises from the bottom of each string: k groups
%            (0 to 11) at a level of 100 to 700 W/m^2. With probability
%            0.5, the group above the edge is in the penumbra (level to
%            1000 W/m^2).
%     group  each group is shaded on its own with probability 0.3, at 100
%            to 900 W/m^2 (stress case).
%   300 patterns of each kind with noise off and on give the 1800 cases
%   of docs/notes/final_test_plan.md, phase 1b.

if nargin < 1, nEach = 300; end
if nargin < 2, seed = 1; end
rs = RandStream('mt19937ar', 'Seed', seed);
kinds = {'panel', 'edge', 'group'};
R = struct('kind', {}, 'k', {}, 'G', {});
for a = 1:3
    for k = 1:nEach
        switch kinds{a}
            case 'panel'
                sh = rand(rs, 4, 4) < 0.4;
                lv = 100 + 800 * rand(rs, 4, 4);
                Gp = 1000 * ones(4, 4); Gp(sh) = lv(sh);
                G  = kron(Gp, ones(3, 1));
            case 'edge'
                G = 1000 * ones(12, 4);
                for c = 1:4
                    n   = randi(rs, [0 11]);
                    lvl = 100 + 600 * rand(rs);
                    G(12 - n + 1:12, c) = lvl;
                    if rand(rs) < 0.5
                        G(12 - n, c) = lvl + (1000 - lvl) * rand(rs);
                    end
                end
            otherwise
                sh = rand(rs, 12, 4) < 0.3;
                lv = 100 + 800 * rand(rs, 12, 4);
                G  = 1000 * ones(12, 4); G(sh) = lv(sh);
        end
        R(end+1) = struct('kind', kinds{a}, 'k', k, 'G', G); %#ok<AGROW>
    end
end
end
