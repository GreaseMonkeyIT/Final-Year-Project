function f = plot_trap(R, name, gm, st)
%PLOT_TRAP Operating points of each decision on the P-V curves of P1 and P3, sets A and B (fig_<alg>_trap.png).
% Color shows the start duty: violet for the start-up duty, aqua for the other.
cStart = st.series([7 3], :);
Vax = 10 * ceil(1.05 * gm('P0').Voc / 10);       % End of the voltage axis [V]
f  = figure('Color', st.bg, 'Position', [100 100 1150 460], 'Visible', 'off');
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for id = {'P1', 'P3'}
    ax = nexttile(tl); hold(ax, 'on');
    g  = gm(id{1});
    Pax = 500 * ceil(1.25 * g.gmpp(2) / 500);     % End of the power axis [W]
    plot(ax, g.V, g.P, 'Color', st.ref, 'LineWidth', 2);
    rr = R(strcmp({R.id}, id{1}) & ismember([R.set], 'AB'));
    h = gobjects(numel(rr), 1); lbl = cell(numel(rr), 1);
    for j = 1:numel(rr)
        c = cStart(min(j, 2), :);
        h(j) = plot(ax, rr(j).Vm, rr(j).Pm, '-o', 'Color', c, 'MarkerSize', 3.5, ...
                    'MarkerFaceColor', c, 'LineWidth', 0.75);
        plot(ax, rr(j).Vm(end), rr(j).Pm(end), 'o', 'MarkerSize', 9, 'MarkerFaceColor', c, ...
             'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.5);
        % Put the label on the side away from the path, so it does not hide the dots.
        if rr(j).Vm(1) > rr(j).Vm(end)
            dx = -0.03 * Vax; ha = 'right';
        else
            dx = 0.03 * Vax; ha = 'left';
        end
        text(ax, rr(j).Vm(end) + dx, rr(j).Pm(end) - 0.025 * Pax, sprintf('stops: %.0f %%', rr(j).pct), ...
             'HorizontalAlignment', ha, 'FontName', st.font, 'FontSize', 8.5, ...
             'Color', st.ink, 'FontWeight', 'bold', 'BackgroundColor', st.bg, 'Margin', 1);
        lbl{j} = sprintf('Start duty %.2f', rr(j).Dstart);
    end
    plot(ax, g.gmpp(1), g.gmpp(2), 'p', 'MarkerSize', 13, 'MarkerFaceColor', st.ink, 'MarkerEdgeColor', [1 1 1]);
    text(ax, g.gmpp(1), g.gmpp(2) + 0.06 * Pax, sprintf('GMPP %.0f W', g.gmpp(2)), 'HorizontalAlignment', 'center', ...
         'FontName', st.font, 'FontSize', 8.5, 'Color', st.ink);
    legend(ax, h, lbl, 'Location', 'northwest', 'Box', 'off', 'FontName', st.font, 'FontSize', 8);
    xlim(ax, [0 Vax]); ylim(ax, [0 Pax]);
    xlabel(ax, 'Array voltage [V]'); ylabel(ax, 'Array power [W]');
    title(ax, sprintf('%s: %s %s', name, g.id, g.name));
    st.axes(ax);
end
end
