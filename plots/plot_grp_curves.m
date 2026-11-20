function f = plot_grp_curves(res, st)
%PLOT_GRP_CURVES Group-level patterns: irradiance of each group and the P-V curve (fig_grp_patterns.png).
%   res comes from results/pv4x4_sweeps_grp.mat (run_gmppt_group.m). Top
%   row: the irradiance of the 48 groups (columns = strings, rows = groups
%   from the top). Bottom row: the P-V curve, with the peaks marked and
%   the global peak labelled.
nP = numel(res);
f  = figure('Color', st.bg, 'Position', [100 100 360 * nP 720], 'Visible', 'off');
tl = tiledlayout(f, 2, nP, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:nP
    r  = res(k);
    ax = nexttile(tl, k);
    imagesc(ax, r.G, [0 1000]);
    colormap(ax, st.seq);
    set(ax, 'XTick', 1:size(r.G, 2), 'YTick', 2:3:size(r.G, 1), 'YTickLabel', {'1', '2', '3', '4'});
    xlabel(ax, 'String'); ylabel(ax, 'Panel row (3 groups each)');
    for y = 3.5:3:size(r.G, 1)
        yline(ax, y, '-', 'Color', [1 1 1], 'LineWidth', 1.5);
    end
    title(ax, sprintf('%s %s', r.id, r.name));
    st.axes(ax); ax.XGrid = 'off'; ax.YGrid = 'off';
    if k == nP
        cb = colorbar(ax); cb.Label.String = 'Irradiance [W/m^2]';
    end

    ax = nexttile(tl, nP + k); hold(ax, 'on');
    plot(ax, r.V, r.P, 'Color', st.series(1,:), 'LineWidth', 1.5);
    plot(ax, r.peaks(:,1), r.peaks(:,2), 'o', 'Color', st.ink2, 'MarkerSize', 5);
    plot(ax, r.gmpp(1), r.gmpp(2), 'o', 'MarkerSize', 8, 'MarkerFaceColor', st.series(8,:), ...
         'MarkerEdgeColor', [1 1 1]);
    text(ax, r.gmpp(1), 1.06 * r.gmpp(2), sprintf('GMPP %.0f W, %.0f V', r.gmpp(2), r.gmpp(1)), ...
         'HorizontalAlignment', 'center', 'FontName', st.font, 'FontSize', 8, 'Color', st.ink);
    xlim(ax, [0 190]); ylim(ax, [0 1.2 * r.gmpp(2)]);
    xlabel(ax, 'Array voltage [V]'); ylabel(ax, 'Array power [W]');
    title(ax, sprintf('%d peaks', size(r.peaks, 1)));
    st.axes(ax);
end
end
