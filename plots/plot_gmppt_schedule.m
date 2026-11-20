function f = plot_gmppt_schedule(groups, titles, tM, pats, algName, algCol, gm, st)
%PLOT_GMPPT_SCHEDULE Power against time when the shading changes (run_gmppt_restart.m).
%   One tile for each cell of groups. Each group is a struct array of
%   runs with the fields alg, t, P and tSearch. Dashed line: the GMPP of
%   each phase. A triangle marks the start of each search. The triangles
%   of each run are at their own height, so that they do not hide each other.
%   tM: phase start times and the stop time. pats: pattern of each phase.
nG = numel(groups);
Pmax = max(arrayfun(@(k) gm(pats{k}).gmpp(2), 1:numel(pats)));
f  = figure('Color', st.bg, 'Position', [100 100 1000 220 + 300 * nG], 'Visible', 'off');
tl = tiledlayout(f, nG, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for gI = 1:nG
    ax = nexttile(tl); hold(ax, 'on');
    for j = 1:numel(pats)
        g = gm(pats{j});
        plot(ax, tM(j:j+1), g.gmpp([2 2]), '--', 'Color', st.ink2, 'LineWidth', 1);
        text(ax, mean(tM(j:j+1)), 1.13 * Pmax, sprintf('%s %s', g.id, g.name), 'HorizontalAlignment', 'center', ...
             'FontName', st.font, 'FontSize', 8.5, 'Color', st.ink, 'FontWeight', 'bold');
        if j > 1, xline(ax, tM(j), ':', 'Color', st.ink2); end
    end
    R = groups{gI};
    h = gobjects(numel(R), 1);
    for k = 1:numel(R)
        c  = algCol(R(k).alg, :);
        sk = R(k).t > 0.005;
        h(k) = plot(ax, R(k).t(sk), R(k).P(sk), 'Color', c, 'LineWidth', 1.1);
        for ts = R(k).tSearch(:)'
            plot(ax, ts, (0.03 + 0.04 * (k - 1)) * Pmax, 'v', 'MarkerSize', 6, 'MarkerFaceColor', c, ...
                 'MarkerEdgeColor', 'none');
        end
    end
    xlim(ax, tM([1 end])); ylim(ax, [0 1.2 * Pmax]);
    ylabel(ax, 'Array power [W]');
    title(ax, titles{gI});
    if gI == nG
        xlabel(ax, 'Time [s]');
    end
    legend(ax, h, algName([R.alg]), 'Location', 'southoutside', 'Orientation', 'horizontal', ...
           'Box', 'off', 'FontName', st.font, 'FontSize', 8.5);
    st.axes(ax);
end
end
