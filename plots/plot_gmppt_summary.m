function f = plot_gmppt_summary(R, algs, algName, algCol, gm, st)
%PLOT_GMPPT_SUMMARY Global searches against P&O from start-up, set A (fig_gmppt_summary.png).
%   Left: final power, % of the global peak. Middle: search probes before
%   the hand-over (global searches only). Right: time after which the
%   power stays at 98 % of the final power or more. One bar for each
%   algorithm in algs, colour algCol(alg, :).
A1 = R([R.set] == 'A' & [R.alg] == algs(1));
nA = numel(A1);
lbl = arrayfun(@(r) sprintf('%s %s', r.id, gm(r.id).name), A1, 'UniformOutput', false);
f  = figure('Color', st.bg, 'Position', [100 100 1400 560], 'Visible', 'off');
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

vals = {'pct', 'nSearch', 't98'};
xlab = {'Final power, % of the global peak', 'Search probes before the hand-over', ...
        'Time to 98 % of the final power [s]'};
ttl  = {'Power reached', 'Cost of the search', 'Time to settle'};
for v = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    aa = algs;
    if v == 2, aa = algs(algs >= 3); end
    x = zeros(nA, numel(aa));
    for i = 1:numel(aa)
        Ai = R([R.set] == 'A' & [R.alg] == aa(i));
        x(:, i) = [Ai.(vals{v})]';
    end
    hb = barh(ax, 1:nA, x, 0.8, 'EdgeColor', 'none');
    for i = 1:numel(aa), hb(i).FaceColor = algCol(aa(i), :); end
    if v == 1
        xline(ax, 100, '-', 'Color', st.ink2);
        xlim(ax, [0 110]); ax.XTick = 0:20:100;
        set(ax, 'YTick', 1:nA, 'YTickLabel', lbl);
    else
        set(ax, 'YTick', 1:nA, 'YTickLabel', {});
    end
    set(ax, 'YDir', 'reverse');
    ylim(ax, [0.4 nA + 0.6]);
    xlabel(ax, xlab{v});
    title(ax, ttl{v});
    legend(ax, hb, algName(aa), 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
           'FontName', st.font, 'FontSize', 8.5);
    st.axes(ax); ax.YGrid = 'off';
end
end
