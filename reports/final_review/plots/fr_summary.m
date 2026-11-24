function T = fr_summary(resDir, outCsv)
%FR_SUMMARY Final comparison table of the five searches over all phases.
%
%   T = fr_summary(resDir) reads the results of the final tests and gives
%   one row for each search: the best (mean) and worst outcome of each
%   phase, the length of the search, the mean processing time of one
%   decision and the compute energy of one search.
%   fr_summary(resDir, outCsv) also writes the table to the CSV file outCsv.
%   Each value names its phase:
%     p1c   start-up in Simulink, 99 patterns: P at 4 s / P_GMPP
%     p1b   start-up on the static bench, all patterns: wrong-peak ends
%     p2    EN 50530 ramps, static bench, 25 degC: dynamic efficiency
%     p3    cloud events, Simulink: efficiency over the event
%     p3n   pattern steps at 30 x sensor noise, static bench
%     p4    full days, T_rescan = 900 s: energy / GMPP energy
%     comp  compiled controller on this PC (estimate of the energy)

algs = [5 3 4 6 7];
C  = load(fullfile(resDir, 'final_p1c.mat'), 'R');
B  = load(fullfile(resDir, 'final_p1b.mat'), 'job', 'res');
P2 = load(fullfile(resDir, 'final_p2.mat'), 'jobs', 'resA', 'var');
P3 = load(fullfile(resDir, 'final_p3.mat'), 'RA', 'key', 'var');
PN = load(fullfile(resDir, 'final_p3n.mat'), 'res', 'job', 'cases', 'var', 'nsc');
P4 = load(fullfile(resDir, 'final_p4.mat'), 'res', 'job', 'var');
CP = load(fullfile(resDir, 'final_compute.mat'), 'res', 'var');
row = @(V, a) find([V.alg] == a & [V.loc] >= 3, 1);   % search a with the parabolic stage or its paper ending
n = numel(algs);
Search = cell(n, 1); x = nan(n, 15);
for i = 1:n
    a = algs(i); Search{i} = fr_names(a);
    X = C.R(C.R(:, 2) == a & ~isnan(C.R(:, 3)), :);
    m = B.job(:, 2) == a & B.job(:, 3) == 1;
    v = row(P2.var, a); e2 = P2.resA(P2.jobs(:, 1) == v & P2.jobs(:, 3) == 1, 1);
    v = row(P3.var, a); e3 = P3.RA(P3.key(:, 2) == v, :); e3 = e3(~isnan(e3(:, 1)), :);
    v = row(PN.var, a); mn = PN.cases(PN.job(:, 1), 1) == 2 & PN.job(:, 2) == v & PN.job(:, 3) == numel(PN.nsc);
    v4 = find([P4.var.alg] == a & [P4.var.loc] >= 3 & [P4.var.Tr] == 900, 1);
    m4 = P4.job(:, 2) == v4; d4 = 100 * P4.res(m4, 1) ./ P4.res(m4, 2);
    v = row(CP.var, a); c = squeeze(mean(CP.res(v, :, :), 2, 'omitnan'));
    x(i, :) = [mean(X(:, 3)), min(X(:, 3)), sum(X(:, 7)), 100 * mean(B.res(m, 5)), mean(B.res(m, 3)), ...
               mean(e2), min(e2), mean(e3(:, 1)), min(e3(:, 1)), mean(e3(:, 5), 'omitnan'), ...
               mean(PN.res(mn, 1)), max(d4), min(d4), c(1), 1e6 * c(8)];
end
T = array2table(x, 'VariableNames', {'p1c_mean_pct', 'p1c_worst_pct', 'p1c_wrong_of_99', 'p1b_wrong_pct', ...
    'search_time_s', 'p2_mean_pct', 'p2_worst_pct', 'p3_mean_pct', 'p3_worst_pct', 'p3_recovery_s', ...
    'p3n_30x_pct', 'p4_best_day_pct', 'p4_worst_day_pct', 'us_per_decision', 'uJ_per_search'});
T = [table(Search) T];
if nargin > 1 && ~isempty(outCsv), writetable(T, outCsv); end
end
