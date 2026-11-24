function f = plot_morning(rc, name, col, gm, st, tM, morning)
%PLOT_MORNING Power and voltage against time for the winter-morning run, set C (fig_<alg>_morning.png).
Pref = gm('P0').gmpp(2);                          % Uniform GMPP [W], sets the power axis
Voc  = gm('P0').Voc;                              % Array Voc [V], sets the voltage axis
f  = figure('Color', st.bg, 'Position', [100 100 1000 560], 'Visible', 'off');
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axP = nexttile(tl); hold(axP, 'on');
axV = nexttile(tl); hold(axV, 'on');
for j = 1:3
    g = gm(morning{j});
    plot(axP, tM(j:j+1), g.gmpp([2 2]), '--', 'Color', st.ink2, 'LineWidth', 1);
    plot(axV, tM(j:j+1), g.gmpp([1 1]), '--', 'Color', st.ink2, 'LineWidth', 1);
    sel = rc.t > tM(j+1) - 0.3 & rc.t <= tM(j+1);
    text(axP, mean(tM(j:j+1)), 1.12 * Pref, sprintf('%s %s', g.id, g.name), 'HorizontalAlignment', 'center', ...
         'FontName', st.font, 'FontSize', 8.5, 'Color', st.ink, 'FontWeight', 'bold');
    text(axP, tM(j+1) - 0.05, mean(rc.P(sel)) - 0.07 * Pref, sprintf('%.0f %% of GMPP', 100 * mean(rc.P(sel)) / g.gmpp(2)), ...
         'HorizontalAlignment', 'right', 'FontName', st.font, 'FontSize', 8.5, 'Color', st.ink);
    if j > 1
        xline(axP, tM(j), ':', 'Color', st.ink2); xline(axV, tM(j), ':', 'Color', st.ink2);
    end
end
sk = rc.t > 0.005;
plot(axP, rc.t(sk), rc.P(sk), 'Color', col, 'LineWidth', 1.25);
plot(axV, rc.t(sk), rc.V(sk), 'Color', col, 'LineWidth', 1.25);
ylim(axP, [0 1.2 * Pref]); xlim(axP, tM([1 4])); xlim(axV, tM([1 4])); ylim(axV, [0.3 1.05] * Voc);
ylabel(axP, 'Array power [W]'); ylabel(axV, 'Array voltage [V]'); xlabel(axV, 'Time [s]');
title(axP, sprintf('%s: Winter morning', name));
st.axes(axP); st.axes(axV);
end
