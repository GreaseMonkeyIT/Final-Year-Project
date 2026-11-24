function fig = fr_noise(resDir)
%FR_NOISE Restart rule under sensor noise (phase p3n, set B: 100 pattern steps).
s = fr_style(); X = load(fullfile(resDir, 'final_p3n.mat'), 'res', 'job', 'cases', 'var', 'nsc');
nm = arrayfun(@final_vname, X.var, 'UniformOutput', false);
fig = figure('Color', 'w', 'Position', [100 100 1000 380]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');
lab = {'Efficiency after the step (%)', 'Runs that end on a wrong peak (of 100)'};
for q = 1:2
    ax = nexttile(tl); hold(ax, 'on');
    for v = 1:numel(X.var)
        y = zeros(size(X.nsc));
        for in = 1:numel(X.nsc)
            m = X.cases(X.job(:, 1), 1) == 2 & X.job(:, 2) == v & X.job(:, 3) == in;
            if q == 1, y(in) = mean(X.res(m, 1)); else, y(in) = sum(X.res(m, 3)); end
        end
        plot(ax, X.nsc, y, '-o', 'Color', s.color(nm{v}), 'MarkerFaceColor', s.color(nm{v}), 'LineWidth', 1.2);
    end
    set(ax, 'XScale', 'log', 'XTick', X.nsc); s.axes(ax);
    xlabel(ax, 'Sensor noise (times the datasheet values)'); ylabel(ax, lab{q});
    if q == 1, legend(ax, nm, 'Location', 'southwest', 'Box', 'off', 'FontSize', 8); end
end
title(tl, 'Phase p3n, set B: 100 steps that move the global peak, static bench', 'FontSize', 10, 'Color', s.ink2);
end
