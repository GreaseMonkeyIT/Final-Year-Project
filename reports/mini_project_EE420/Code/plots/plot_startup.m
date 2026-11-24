function f = plot_startup(R, name, col, gm, st)
%PLOT_STARTUP Power reached from start-up (set A), one bar for each pattern (fig_<alg>_startup.png).
%   R holds the runs of one algorithm. gm(id) returns the sweep result of pattern id.
A  = R([R.set] == 'A');
nA = numel(A);
f  = figure('Color', st.bg, 'Position', [100 100 820 430], 'Visible', 'off');
ax = axes(f); hold(ax, 'on');
pct = [A.pct];
barh(ax, 1:nA, pct, 0.6, 'FaceColor', col, 'EdgeColor', 'none');
plot(ax, [100 100], [0 nA + 1], '-', 'Color', st.ink2, 'LineWidth', 0.75);   % Under the labels
for k = 1:nA
    g = gm(A(k).id);
    text(ax, pct(k) + 1.5, k, sprintf('%.0f %%   %.0f of %.0f W, %s', pct(k), A(k).Pend, g.gmpp(2), A(k).onPeak), ...
         'FontName', st.font, 'FontSize', 8, 'Color', st.ink, 'VerticalAlignment', 'middle', ...
         'BackgroundColor', st.bg, 'Margin', 1);
end
set(ax, 'YTick', 1:nA, 'YTickLabel', arrayfun(@(r) sprintf('%s %s', r.id, gm(r.id).name), A, ...
    'UniformOutput', false), 'YDir', 'reverse');
xlim(ax, [0 175]); ylim(ax, [0.4 nA + 0.6]); ax.XTick = 0:20:100;
xlabel(ax, sprintf('Power reached by %s, %% of the global peak', name));
title(ax, sprintf('%s: Start-up', name));
st.axes(ax); ax.YGrid = 'off';
end
