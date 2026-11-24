function f = plot_slide_pair(res, cfg, st)
%PLOT_SLIDE_PAIR Slide layout: uniform P0 on the left, shaded P1 to P3 on the right (fig_slide_pair.png).
%   Each column has I-V on top and P-V below. Red dots mark the key points.
%   On the right, a filled dot is the global peak and a hollow dot is a local peak.
[Vax, Pax, Iax] = sweep_axes(res, cfg);
red = [0.85 0.1 0.1];
f = figure('Color', st.bg, 'Position', [100 100 1250 620], 'Visible', 'off');
tl = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axI0 = nexttile(tl, 1); hold(axI0, 'on');      % Row 1: I-V
axI1 = nexttile(tl, 2); hold(axI1, 'on');
axP0 = nexttile(tl, 3); hold(axP0, 'on');      % Row 2: P-V
axP1 = nexttile(tl, 4); hold(axP1, 'on');

%% Left: P0, uniform irradiance
r0 = res(1);
blue = st.series(1,:);
[~, iMp] = min(abs(r0.V - r0.gmpp(1)));
Vmp = r0.gmpp(1); Pm = r0.gmpp(2); Imp = r0.I(iMp);
Isc = r0.I(1); Voc = r0.V(end);
plot(axI0, r0.V, r0.I, 'Color', blue, 'LineWidth', 1.5);
plot(axP0, r0.V, r0.P, 'Color', blue, 'LineWidth', 1.5);
plot(axI0, [Vmp Vmp], [0 Iax], '--', 'Color', red, 'LineWidth', 1.2);
plot(axP0, [Vmp Vmp], [0 Pax], '--', 'Color', red, 'LineWidth', 1.2);
dots = @(ax, x, y) plot(ax, x, y, 'o', 'MarkerSize', 6, 'MarkerFaceColor', red, 'MarkerEdgeColor', red);
dots(axI0, [0 Vmp Voc], [Isc Imp 0]);
dots(axP0, Vmp, Pm);
lab = @(ax, x, y, s, ha) text(ax, x, y, s, 'FontName', st.font, 'FontSize', 9, ...
    'FontWeight', 'bold', 'Color', st.ink, 'HorizontalAlignment', ha, 'VerticalAlignment', 'bottom');
lab(axI0, 0.02 * Vax, Isc + 0.03 * Iax, 'I_{sc}', 'left');
lab(axI0, Vmp + 0.02 * Vax, Imp + 0.03 * Iax, 'V_{mp}, I_{mp}', 'left');
lab(axI0, Voc, 0.05 * Iax, 'V_{oc}', 'center');
lab(axP0, Vmp + 0.02 * Vax, Pm + 0.02 * Pax, 'P_m', 'left');

%% Right: P1 to P3, partial shading
nS = min(4, numel(res)) - 1;
hI = gobjects(nS, 1);
for k = 1:nS
    r = res(k + 1);
    c = st.series(k,:);
    hI(k) = plot(axI1, r.V, r.I, 'Color', c, 'LineWidth', 1.5);
    plot(axP1, r.V, r.P, 'Color', c, 'LineWidth', 1.5);
end
for k = 1:nS
    r = res(k + 1);
    c = st.series(k,:);
    pk = r.peaks;
    loc = pk(:,2) < r.gmpp(2) - 1;
    plot(axP1, pk(loc,1), pk(loc,2), 'o', 'MarkerSize', 6, 'MarkerFaceColor', [1 1 1], ...
         'MarkerEdgeColor', red, 'LineWidth', 1.25);
    plot(axP1, r.gmpp(1), r.gmpp(2), 'o', 'MarkerSize', 7, 'MarkerFaceColor', red, 'MarkerEdgeColor', red);
    [~, i] = min(abs(r.V - r.gmpp(1)));
    plot(axI1, r.gmpp(1), r.I(i), 'o', 'MarkerSize', 6, 'MarkerFaceColor', red, 'MarkerEdgeColor', red);
    text(axP1, r.gmpp(1), r.gmpp(2) + 0.03 * Pax, sprintf('%s GMPP', r.id), 'FontName', st.font, ...
         'FontSize', 8.5, 'FontWeight', 'bold', 'Color', c, 'HorizontalAlignment', 'center', ...
         'VerticalAlignment', 'bottom');
end
names = arrayfun(@(r) sprintf('%s %s', r.id, r.name), res(2:nS+1), 'UniformOutput', false);
legend(axI1, hI, names, 'Location', 'southwest', 'Box', 'off', 'FontName', st.font, 'FontSize', 8.5);

%% Axes
ax = [axI0 axI1 axP0 axP1];
for a = ax, xlim(a, [0 Vax]); st.axes(a); end
ylim(axI0, [0 Iax]); ylim(axI1, [0 Iax]);
ylim(axP0, [0 Pax]); ylim(axP1, [0 Pax]);
ylabel(axI0, 'Current [A]'); ylabel(axP0, 'Power [W]');
xlabel(axP0, 'Voltage [V]'); xlabel(axP1, 'Voltage [V]');
set([axI0 axI1], 'XTickLabel', []);
title(axI0, 'P0 Uniform irradiance'); title(axI1, 'P1 to P3 Partial shading');
end
