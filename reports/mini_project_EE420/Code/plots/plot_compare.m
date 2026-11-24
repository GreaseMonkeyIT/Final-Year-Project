function f = plot_compare(R, algs, algName, algCol, gm, st, tM, morning)
%PLOT_COMPARE P&O and INC side by side (fig_po_vs_inc.png).
% Left: power reached from start-up (set A), P&O and INC side by side.
% Right: array voltage in the winter-morning run, both algorithms.
Voc = gm('P0').Voc;                               % Array Voc [V], sets the voltage axis
f  = figure('Color', st.bg, 'Position', [100 100 1300 520], 'Visible', 'off');
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

ax = nexttile(tl); hold(ax, 'on');
A1  = R([R.set] == 'A' & [R.alg] == algs(1));
nA  = numel(A1);
pct = zeros(nA, numel(algs));
for i = 1:numel(algs)
    Ai = R([R.set] == 'A' & [R.alg] == algs(i));
    pct(:, i) = [Ai.pct]';
end
hb = barh(ax, 1:nA, pct, 0.8, 'EdgeColor', 'none');
for i = 1:numel(algs), hb(i).FaceColor = algCol(algs(i), :); end
plot(ax, [100 100], [0 nA + 1], '-', 'Color', st.ink2, 'LineWidth', 0.75);   % Under the labels
for k = 1:nA
    text(ax, max(pct(k,:)) + 2, k, sprintf('%.0f / %.0f %%', pct(k,1), pct(k,end)), 'FontName', st.font, ...
         'FontSize', 8, 'Color', st.ink, 'VerticalAlignment', 'middle', 'BackgroundColor', st.bg, 'Margin', 1);
end
set(ax, 'YTick', 1:nA, 'YTickLabel', arrayfun(@(r) sprintf('%s %s', r.id, gm(r.id).name), A1, ...
    'UniformOutput', false), 'YDir', 'reverse');
xlim(ax, [0 130]); ax.XTick = 0:20:100; ylim(ax, [0.4 nA + 0.6]);
legend(ax, hb, algName(algs), 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
       'FontName', st.font, 'FontSize', 8.5);
xlabel(ax, 'Power reached from start-up, % of the global peak');
title(ax, 'Start-up');
st.axes(ax); ax.YGrid = 'off';

ax = nexttile(tl); hold(ax, 'on');
for j = 1:3
    g = gm(morning{j});
    plot(ax, tM(j:j+1), g.gmpp([1 1]), '--', 'Color', st.ink2, 'LineWidth', 1);
    text(ax, mean(tM(j:j+1)), 1.03 * Voc, sprintf('%s %s', g.id, g.name), 'HorizontalAlignment', 'center', ...
         'FontName', st.font, 'FontSize', 8.5, 'Color', st.ink, 'FontWeight', 'bold');
    if j > 1, xline(ax, tM(j), ':', 'Color', st.ink2); end
end
h = gobjects(numel(algs), 1);
for i = 1:numel(algs)
    rc = R([R.set] == 'C' & [R.alg] == algs(i));
    sk = rc.t > 0.005;
    h(i) = plot(ax, rc.t(sk), rc.V(sk), 'Color', algCol(algs(i), :), 'LineWidth', 1.25);
end
legend(ax, h, algName(algs), 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
       'FontName', st.font, 'FontSize', 8.5);
xlim(ax, tM([1 4])); ylim(ax, [0.45 1.07] * Voc);
xlabel(ax, 'Time [s]'); ylabel(ax, 'Array voltage [V]');
title(ax, 'Winter morning');
st.axes(ax);
end
