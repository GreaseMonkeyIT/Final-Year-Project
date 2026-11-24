function fig = fr_search_points(resDir)
%FR_SEARCH_POINTS Settled samples of each global search on the P-V curve of R1.
s = fr_style(); T = load(fullfile(resDir, 'final_traces.mat'), 'A', 'A_curve');
A = T.A; c = T.A_curve;
fig = figure('Color', 'w', 'Position', [100 100 1000 420]);
tl = tiledlayout(fig, 1, numel(A), 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:numel(A)
    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, c.Vg, c.P / 1000, 'Color', s.ref, 'LineWidth', 1.2);
    plot(ax, A(k).Vs, A(k).Ps / 1000, 'o', 'MarkerSize', 5, 'Color', s.color(A(k).name), ...
         'MarkerFaceColor', s.color(A(k).name));
    plot(ax, A(k).Vend, A(k).Pend / 1000, 'p', 'MarkerSize', 12, 'Color', s.ink, 'MarkerFaceColor', 'w');
    title(ax, {A(k).name, sprintf('%d samples, %.2f s', numel(A(k).Vs), A(k).tEnd)}, 'FontSize', 9);
    xlim(ax, [0 200]); ylim(ax, [0 1.1 * c.gmpp(2) / 1000]); s.axes(ax);
    xlabel(ax, 'Voltage (V)');
    if k == 1, ylabel(ax, 'Power (kW)'); end
end
title(tl, 'Samples of each search on pattern R1 (static bench). Star: operating point at 4 s', ...
      'FontSize', 10, 'Color', s.ink2);
end
