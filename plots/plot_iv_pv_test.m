function f = plot_iv_pv_test(res, cfg, st)
%PLOT_IV_PV_TEST I-V and P-V of the test patterns P0 to P3 (fig_iv_pv_test.png).
[Vax, Pax, Iax] = sweep_axes(res, cfg);
nP = numel(res);
f = figure('Color', st.bg, 'Position', [100 100 1100 430], 'Visible', 'off');
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axI = nexttile(tl); hold(axI, 'on');
axP = nexttile(tl); hold(axP, 'on');
col = [st.ink2; st.series];             % P0 reference, then P1, P2, ...
sty = [{'--'}, repmat({'-'}, 1, nP - 1)];
hI = gobjects(4, 1);
for k = 1:4
    c = col(k,:);
    hI(k) = plot(axI, res(k).V, res(k).I, sty{k}, 'Color', c, 'LineWidth', 1.5);
    plot(axP, res(k).V, res(k).P, sty{k}, 'Color', c, 'LineWidth', 1.5);
    plot(axP, res(k).gmpp(1), res(k).gmpp(2), 'o', 'MarkerSize', 7, 'MarkerFaceColor', c, ...
         'MarkerEdgeColor', [1 1 1]);
end
names = arrayfun(@(r) sprintf('%s %s', r.id, r.name), res(1:4), 'UniformOutput', false);
legend(axI, hI, names, 'Location', 'southwest', 'Box', 'off', 'FontName', st.font, 'FontSize', 8);
for k = 1:4
    text(axP, res(k).gmpp(1) + 0.015 * Vax, res(k).gmpp(2) + 0.03 * Pax, res(k).id, 'FontName', st.font, ...
         'FontSize', 8, 'Color', st.ink, 'FontWeight', 'bold');
end
xlabel(axI, 'Array voltage [V]'); ylabel(axI, 'Array current [A]');
xlabel(axP, 'Array voltage [V]'); ylabel(axP, 'Array power [W]');
xlim(axI, [0 Vax]); xlim(axP, [0 Vax]); ylim(axI, [0 Iax]); ylim(axP, [0 Pax]);
st.axes(axI); st.axes(axP);
end
