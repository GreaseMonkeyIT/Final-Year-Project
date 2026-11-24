function fig = fr_startup_stats(resDir)
%FR_STARTUP_STATS Start-up accuracy of the five searches.
%   Left: phase 1c (Simulink, 99 patterns): mean and worst power at 4 s
%   over the GMPP power, and the runs that end on a wrong peak.
%   Right: phase 1b (static bench, all patterns, sensors on, 25 degC):
%   share of runs whose shortfall from the GMPP power is above x (log axis).
s = fr_style();
C = load(fullfile(resDir, 'final_p1c.mat'), 'R');
B = load(fullfile(resDir, 'final_p1b.mat'), 'job', 'res');
algs = [5 3 4 6 7];                        % Idea C first, then the order of fr_style
fig = figure('Color', 'w', 'Position', [100 100 1000 380]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');
ax = nexttile(tl); hold(ax, 'on');
for i = 1:numel(algs)
    X = C.R(C.R(:, 2) == algs(i) & ~isnan(C.R(:, 3)), :);
    nm = fr_names(algs(i)); col = s.color(nm);
    plot(ax, [i i], [min(X(:, 3)) mean(X(:, 3))], '-', 'Color', col, 'LineWidth', 2);
    plot(ax, i, mean(X(:, 3)), 'o', 'MarkerSize', 8, 'Color', col, 'MarkerFaceColor', col);
    plot(ax, i, min(X(:, 3)), 'v', 'MarkerSize', 7, 'Color', col, 'MarkerFaceColor', 'w');
    % One label under the worst marker: four searches sit near 100 %, so
    % labels beside the markers overlap.
    text(ax, i, min(X(:, 3)) - 0.2, sprintf('mean %.3f\nworst %.2f\n%d wrong', mean(X(:, 3)), min(X(:, 3)), sum(X(:, 7))), ...
         'FontSize', 8, 'Color', s.ink, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
end
set(ax, 'XTick', 1:numel(algs), 'XTickLabel', arrayfun(@(a) strtok(fr_names(a), '+'), algs, 'UniformOutput', false));
xlim(ax, [0.4 numel(algs) + 0.6]); ylim(ax, [88.5 100.4]); s.axes(ax);
ylabel(ax, 'P at 4 s / P_{GMPP} (%)');
title(ax, 'Simulink, 99 patterns: mean (dot) and worst (triangle)');
ax = nexttile(tl); hold(ax, 'on');
% Shortfall 100 - P/P_GMPP on a log axis: most runs end within 0.1 % of
% the GMPP power, so a linear axis puts every curve against 100 %.
x = logspace(-3, 1.3, 400);
for i = 1:numel(algs)
    m = B.job(:, 2) == algs(i) & B.job(:, 3) == 1 & B.job(:, 5) == 1;
    sf = 100 - B.res(m, 1);
    plot(ax, x, 100 * arrayfun(@(q) mean(sf > q), x), 'Color', s.color(fr_names(algs(i))), 'LineWidth', 1.5);
end
set(ax, 'XScale', 'log'); xlim(ax, x([1 end])); ylim(ax, [0 101]); s.axes(ax);
xlabel(ax, 'x: shortfall at 4 s, 100 - P / P_{GMPP} (%)'); ylabel(ax, 'Runs with a shortfall above x (%)');
legend(ax, arrayfun(@fr_names, algs, 'UniformOutput', false), 'Location', 'northeast', 'Box', 'off', 'FontSize', 8);
title(ax, 'Static bench, all patterns, sensors on, 25 °C');
end
