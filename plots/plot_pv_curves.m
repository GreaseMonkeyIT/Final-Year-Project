function f = plot_pv_curves(res, cfg, st)
%PLOT_PV_CURVES P-V curve of each pattern, with the uniform curve for reference (fig_pv_curves.png).
[Vax, Pax] = sweep_axes(res, cfg);
nP = numel(res);
f = figure('Color', st.bg, 'Position', [100 100 1100 850], 'Visible', 'off');
tl = tiledlayout(f, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:nP
    ax = nexttile(tl); hold(ax, 'on');
    if k > 1
        plot(ax, res(1).V, res(1).P, 'Color', st.ref, 'LineWidth', 1);
    end
    plot(ax, res(k).V, res(k).P, 'Color', st.series(1,:), 'LineWidth', 1.5);
    pk = res(k).peaks;
    loc = pk(:,2) < res(k).gmpp(2) - 1;
    plot(ax, pk(loc,1), pk(loc,2), 'o', 'MarkerSize', 6, 'MarkerFaceColor', [1 1 1], ...
         'MarkerEdgeColor', st.series(1,:), 'LineWidth', 1.25);
    plot(ax, res(k).gmpp(1), res(k).gmpp(2), 'o', 'MarkerSize', 7, ...
         'MarkerFaceColor', st.series(1,:), 'MarkerEdgeColor', [1 1 1], 'LineWidth', 1);
    text(ax, res(k).gmpp(1), res(k).gmpp(2) + 0.05 * Pax, sprintf('GMPP %.0f W, %.1f V', res(k).gmpp(2), res(k).gmpp(1)), ...
         'HorizontalAlignment', 'center', 'FontName', st.font, 'FontSize', 8, 'Color', st.ink);
    xlim(ax, [0 Vax]); ylim(ax, [0 Pax]);
    title(ax, sprintf('%s  %s', res(k).id, res(k).name));
    st.axes(ax);
    if k > 6, xlabel(ax, 'Array voltage [V]'); end
    if mod(k, 3) == 1, ylabel(ax, 'Array power [W]'); end
end
end
