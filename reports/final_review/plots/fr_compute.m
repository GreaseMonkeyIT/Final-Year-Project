function fig = fr_compute(resDir)
%FR_COMPUTE Execution time of one decision and compute energy of one search (phase compute).
s = fr_style(); X = load(fullfile(resDir, 'final_compute.mat'), 'res', 'var', 'Pcore');
nm = arrayfun(@final_vname, X.var, 'UniformOutput', false);
x = squeeze(mean(X.res, 2, 'omitnan'));    % variants x 8
fig = figure('Color', 'w', 'Position', [100 100 1000 360]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');
col = [1 8]; sc = [1 1e6];
lab = {'Mean time of one decision (us, this PC)', 'Compute energy of one search (uJ, estimate)'};
for q = 1:2
    ax = nexttile(tl); hold(ax, 'on');
    for v = 1:numel(nm)
        y = x(v, col(q)) * sc(q);
        bar(ax, v, y, 0.6, 'FaceColor', s.color(nm{v}), 'EdgeColor', 'none');
        text(ax, v, y, sprintf('%.3g', y), 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'bottom', 'FontSize', 8, 'Color', s.ink);
    end
    set(ax, 'XTick', 1:numel(nm), 'XTickLabel', strtok(nm, '+'));
    s.axes(ax);
    ylabel(ax, lab{q});
end
title(tl, sprintf('Compiled controller on one core of the PC (AMD Ryzen 9 8940HX, %.1f W per core, estimate)', ...
      X.Pcore), 'FontSize', 10, 'Color', s.ink2);
end
