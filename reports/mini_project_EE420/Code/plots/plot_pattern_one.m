function f = plot_pattern_one(res, id, cfg, st)
%PLOT_PATTERN_ONE Irradiance, I-V, and P-V of one pattern, with its peaks marked.
%   res is the struct array of results/pv4x4_sweeps.mat. id is a pattern
%   ID, for example 'P3'. The uniform pattern P0 is the gray reference.
[Vax, Pax, Iax] = sweep_axes(res, cfg);
r   = res(strcmp({res.id}, id));
c   = st.series(1,:);
f   = figure('Color', st.bg, 'Position', [100 100 1300 430], 'Visible', 'off');
tl  = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% Irradiance of each panel
ax = nexttile(tl);
cmap = interp1(linspace(0, 1, size(st.seq, 1)), st.seq, linspace(0, 1, 256));
imagesc(ax, r.G, [100 1000]); colormap(ax, cmap); axis(ax, 'image'); hold(ax, 'on');
for k = 1.5:1:size(r.G, 2)            % White gaps between the strings
    plot(ax, [k k], [0.5 size(r.G,1)+0.5], 'Color', [1 1 1], 'LineWidth', 4);
end
for i = 1:size(r.G, 1)
    for j = 1:size(r.G, 2)
        lum = r.G(i,j) < 550;
        text(ax, j, i, sprintf('%d', r.G(i,j)), 'HorizontalAlignment', 'center', ...
             'FontName', st.font, 'FontSize', 9, 'Color', lum * st.ink + ~lum * [1 1 1]);
    end
end
set(ax, 'XTick', 1:4, 'XTickLabel', {'S1', 'S2', 'S3', 'S4'}, 'YTick', 1:4, ...
    'YTickLabel', {'Row 1', 'Row 2', 'Row 3', 'Row 4'}, 'TickLength', [0 0], 'FontName', st.font, ...
    'FontSize', 8, 'XColor', st.ink2, 'YColor', st.ink2);

% I-V
ax = nexttile(tl); hold(ax, 'on');
if ~strcmp(id, 'P0'), plot(ax, res(1).V, res(1).I, 'Color', st.ref, 'LineWidth', 1); end
plot(ax, r.V, r.I, 'Color', c, 'LineWidth', 1.5);
xlim(ax, [0 Vax]); ylim(ax, [0 Iax]);
xlabel(ax, 'Array voltage [V]'); ylabel(ax, 'Array current [A]');
st.axes(ax);

% P-V, peaks marked
ax = nexttile(tl); hold(ax, 'on');
if ~strcmp(id, 'P0'), plot(ax, res(1).V, res(1).P, 'Color', st.ref, 'LineWidth', 1); end
plot(ax, r.V, r.P, 'Color', c, 'LineWidth', 1.5);
pk  = r.peaks;
loc = pk(:,2) < r.gmpp(2) - 1;
plot(ax, pk(loc,1), pk(loc,2), 'o', 'MarkerSize', 6, 'MarkerFaceColor', [1 1 1], ...
     'MarkerEdgeColor', c, 'LineWidth', 1.25);
plot(ax, r.gmpp(1), r.gmpp(2), 'o', 'MarkerSize', 7, 'MarkerFaceColor', c, ...
     'MarkerEdgeColor', [1 1 1], 'LineWidth', 1);
for k = find(loc)'
    text(ax, pk(k,1), pk(k,2) - 0.05 * Pax, sprintf('%.0f W, %.1f V', pk(k,2), pk(k,1)), ...
         'HorizontalAlignment', 'center', 'FontName', st.font, 'FontSize', 8, 'Color', st.ink2);
end
text(ax, r.gmpp(1), r.gmpp(2) + 0.05 * Pax, sprintf('GMPP %.0f W, %.1f V', r.gmpp(2), r.gmpp(1)), ...
     'HorizontalAlignment', 'center', 'FontName', st.font, 'FontSize', 8, 'Color', st.ink);
xlim(ax, [0 Vax]); ylim(ax, [0 Pax]);
xlabel(ax, 'Array voltage [V]'); ylabel(ax, 'Array power [W]');
st.axes(ax);

title(tl, sprintf('%s  %s', r.id, r.name), 'FontName', st.font, 'FontSize', 10, 'Color', st.ink, ...
      'FontWeight', 'bold');
end
