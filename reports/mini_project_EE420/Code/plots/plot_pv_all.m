function f = plot_pv_all(res, cfg, st)
%PLOT_PV_ALL All nine P-V curves on one graph (fig_pv_all.png).
[Vax, Pax] = sweep_axes(res, cfg);
nP = numel(res);
col = [st.ink2; st.series];             % P0 reference, then P1, P2, ...
sty = [{'--'}, repmat({'-'}, 1, nP - 1)];
f = figure('Color', st.bg, 'Position', [100 100 1250 620], 'Visible', 'off');
ax = axes(f); hold(ax, 'on');
h  = gobjects(nP, 1);
for k = 1:nP
    h(k) = plot(ax, res(k).V, res(k).P, sty{k}, 'Color', col(k,:), 'LineWidth', 1.5);
end
g = reshape([res.gmpp], 2, [])';          % Global peak of each pattern: [V P]
for k = 1:nP                              % Dots after the lines, so they are on top
    plot(ax, g(k,1), g(k,2), 'o', 'MarkerSize', 7, 'MarkerFaceColor', col(k,:), ...
         'MarkerEdgeColor', [1 1 1], 'LineWidth', 1);
end
% Label each dot with its pattern ID, to the right of the dot. Go from the
% highest peak to the lowest. If a label is near a label already placed,
% move it down, and draw a short leader line to its dot.
ly = g(:,2);
[~, order] = sort(g(:,2), 'descend');
placed = [];
for k = order'
    y = g(k,2);
    moved = true;
    while moved
        moved = false;
        for j = placed
            if abs(g(j,1) - g(k,1)) < 0.13 * Vax && abs(ly(j) - y) < 0.03 * Pax
                y = ly(j) - 0.03 * Pax;
                moved = true;
            end
        end
    end
    ly(k) = y;
    placed(end+1) = k; %#ok<AGROW>
end
for k = 1:nP
    if abs(ly(k) - g(k,2)) > 1
        plot(ax, [g(k,1) g(k,1) + 0.025 * Vax], [g(k,2) ly(k)], '-', 'Color', st.ink2, 'LineWidth', 0.5);
    end
    text(ax, g(k,1) + 0.028 * Vax, ly(k), res(k).id, 'FontName', st.font, 'FontSize', 8, ...
         'FontWeight', 'bold', 'Color', st.ink, 'VerticalAlignment', 'middle', ...
         'BackgroundColor', st.bg, 'Margin', 0.5);
end
names = arrayfun(@(r) sprintf('%s %s', r.id, r.name), res, 'UniformOutput', false);
legend(ax, h, names, 'Location', 'eastoutside', 'Box', 'off', 'FontName', st.font, 'FontSize', 8.5);
xlim(ax, [0 Vax]); ylim(ax, [0 Pax]);
xlabel(ax, 'Array voltage [V]'); ylabel(ax, 'Array power [W]');
st.axes(ax);
end
