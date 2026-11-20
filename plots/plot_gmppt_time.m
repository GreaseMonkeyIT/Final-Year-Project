function f = plot_gmppt_time(R, ids, algs, algName, algCol, gm, st)
%PLOT_GMPPT_TIME Power against time from start-up for some patterns, set A (fig_gmppt_time.png).
%   One tile for each pattern in ids, one line for each algorithm in
%   algs. Dashed line: global peak. A dot marks the hand-over to P&O.
tEnd = 1.5;                                       % End of the time axis [s]
f  = figure('Color', st.bg, 'Position', [100 100 1000 250 + 230 * numel(ids)], 'Visible', 'off');
tl = tiledlayout(f, numel(ids), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:numel(ids)
    ax = nexttile(tl); hold(ax, 'on');
    g  = gm(ids{k});
    plot(ax, [0 tEnd], g.gmpp([2 2]), '--', 'Color', st.ink2, 'LineWidth', 1);
    h = gobjects(numel(algs), 1);
    for i = 1:numel(algs)
        r  = R([R.set] == 'A' & [R.alg] == algs(i) & strcmp({R.id}, ids{k}));
        sk = r.t > 0.005 & r.t <= tEnd;
        h(i) = plot(ax, r.t(sk), r.P(sk), 'Color', algCol(algs(i), :), 'LineWidth', 1.1);
        if algs(i) >= 3
            [~, j] = min(abs(r.t - r.tHand));
            plot(ax, r.t(j), r.P(j), 'o', 'MarkerSize', 6, 'MarkerFaceColor', algCol(algs(i), :), ...
                 'MarkerEdgeColor', [1 1 1]);
        end
    end
    xlim(ax, [0 tEnd]); ylim(ax, [0 1.15 * g.gmpp(2)]);
    ylabel(ax, 'Array power [W]');
    title(ax, sprintf('%s %s: GMPP %.0f W', g.id, g.name, g.gmpp(2)));
    if k == numel(ids)
        xlabel(ax, 'Time [s]');
        legend(ax, h, algName(algs), 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
               'FontName', st.font, 'FontSize', 8.5);
    end
    st.axes(ax);
end
end
