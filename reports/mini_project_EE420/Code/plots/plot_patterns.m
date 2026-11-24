function f = plot_patterns(res, st)
%PLOT_PATTERNS Irradiance of each panel, for each pattern (fig_patterns.png).
%   res is the struct array of results/pv4x4_sweeps.mat. st = plot_style().
nP = numel(res);
f = figure('Color', st.bg, 'Position', [100 100 900 900], 'Visible', 'off');
tl = tiledlayout(f, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
cmap = interp1(linspace(0, 1, size(st.seq, 1)), st.seq, linspace(0, 1, 256));
for k = 1:nP
    ax = nexttile(tl);
    G = res(k).G;
    imagesc(ax, G, [100 1000]); colormap(ax, cmap); axis(ax, 'image');
    hold(ax, 'on');
    for c = 1.5:1:size(G, 2)      % White gaps between the strings
        plot(ax, [c c], [0.5 size(G,1)+0.5], 'Color', [1 1 1], 'LineWidth', 4);
    end
    for r = 1:size(G, 1)
        for c = 1:size(G, 2)
            lum = G(r,c) < 550;
            text(ax, c, r, sprintf('%d', G(r,c)), 'HorizontalAlignment', 'center', ...
                 'FontName', st.font, 'FontSize', 9, 'Color', lum * st.ink + ~lum * [1 1 1]);
        end
    end
    set(ax, 'XTick', 1:4, 'XTickLabel', {'S1', 'S2', 'S3', 'S4'}, 'YTick', 1:4, ...
        'YTickLabel', {'Row 1', 'Row 2', 'Row 3', 'Row 4'}, 'TickLength', [0 0], 'FontName', st.font, ...
        'FontSize', 8, 'XColor', st.ink2, 'YColor', st.ink2);
    title(ax, sprintf('%s  %s', res(k).id, res(k).name), 'FontName', st.font, 'FontSize', 9, ...
          'Color', st.ink, 'FontWeight', 'bold');
end
end
