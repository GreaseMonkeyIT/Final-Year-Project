function fig = fr_cloud_stats(resDir)
%FR_CLOUD_STATS Cloud events of phase 3 (Simulink): efficiency and recovery time per event.
s = fr_style(); X = load(fullfile(resDir, 'final_p3.mat'), 'RA', 'key', 'var');
nV = numel(X.var); nm = arrayfun(@final_vname, X.var, 'UniformOutput', false);
fig = figure('Color', 'w', 'Position', [100 100 1000 380]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');
lab = {'Efficiency over the event (%)', 'Recovery time to 99 % of GMPP (s)'}; col = [1 5];
for q = 1:2
    ax = nexttile(tl); hold(ax, 'on');
    for v = 1:nV
        y = X.RA(X.key(:, 2) == v, col(q)); y = y(~isnan(y));
        xj = v + 0.25 * (rand(size(y)) - 0.5);
        scatter(ax, xj, y, 12, s.color(nm{v}), 'filled', 'MarkerFaceAlpha', 0.6);
        plot(ax, v + [-0.3 0.3], median(y) * [1 1], '-', 'Color', s.ink, 'LineWidth', 1.5);
    end
    set(ax, 'XTick', 1:nV, 'XTickLabel', strtok(nm, '+')); xlim(ax, [0.5 nV + 0.5]); s.axes(ax);
    ylabel(ax, lab{q});
end
title(tl, 'Phase 3: 40 cloud events, Simulink, sensors on. Dots: events, bar: median', 'FontSize', 10, 'Color', s.ink2);
end
