function fig = fr_pv_patterns(~)
%FR_PV_PATTERNS P-V curves of the nine shading patterns, global peak marked.
s = fr_style(); cfg = pv4x4_config(); pats = shading_patterns();
fig = figure('Color', 'w', 'Position', [100 100 900 640]);
tl = tiledlayout(fig, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:min(9, numel(pats))
    b = bench_curve(pats(k).G, 25, cfg);
    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, b.Vg, b.Vg .* b.I / 1000, 'Color', s.pal(1, :), 'LineWidth', 1.5);
    plot(ax, b.peaks(:, 1), b.peaks(:, 2) / 1000, 'o', 'MarkerSize', 5, 'Color', s.ink2, 'MarkerFaceColor', 'w');
    plot(ax, b.gmpp(1), b.gmpp(2) / 1000, 'o', 'MarkerSize', 7, 'Color', s.ink, 'MarkerFaceColor', s.ink);
    text(ax, b.gmpp(1), b.gmpp(2) / 1000, sprintf('  %.2f kW', b.gmpp(2) / 1000), 'FontSize', 8, ...
         'Color', s.ink, 'VerticalAlignment', 'bottom');
    np = size(b.peaks, 1); if np == 1, w = 'peak'; else, w = 'peaks'; end
    title(ax, sprintf('%s: %d %s', pats(k).id, np, w));
    xlim(ax, [0 200]); ylim(ax, [0 5.6]); s.axes(ax);
    if k > 6, xlabel(ax, 'Array voltage (V)'); end
    if mod(k, 3) == 1, ylabel(ax, 'Power (kW)'); end
end
title(tl, 'P-V curves of the shading patterns (25 °C). Filled dot: global peak, open dots: local peaks', ...
      'FontSize', 10, 'Color', s.ink2);
end
