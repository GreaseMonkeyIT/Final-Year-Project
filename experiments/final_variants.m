function var = final_variants(withBase)
%FINAL_VARIANTS The variants of the final comparison (2026-11-23).
%
%   var = final_variants() gives the five searches as a struct array with
%   the fields alg and loc (see final_variant.m): DIRECT as in its paper,
%   and Idea B, Idea C, PSO and GWO with the parabolic stage.
%   var = final_variants(true) adds P&O and INC from start-up.

var = struct('alg', {3, 4, 5, 6, 7}, 'loc', {5, 3, 3, 3, 3});
if nargin > 0 && withBase
    var = [var, struct('alg', {1, 2}, 'loc', {0, 0})];
end
end
