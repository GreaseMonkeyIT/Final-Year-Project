function s = fr_style()
%FR_STYLE Colors and axes settings of the figures of the final review.
%
%   s = fr_style() gives the colors of the variants and a function that
%   formats an axes: s.axes(ax). The colors are the categorical palette of
%   the mid review (plot_style.m), checked for colour vision deficiency.
%   Each variant keeps its colour in every figure. Idea C (the final
%   approach) has the colour with the most contrast. Three colours have a
%   low contrast on white, so each figure has a legend or direct labels.

hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
pal = [hex('#2a78d6'); hex('#eb6834'); hex('#1baf7a'); hex('#eda100'); ...
       hex('#e87ba4'); hex('#008300'); hex('#4a3aa7'); hex('#e34948')];
s.order = {'Idea C', 'DIRECT', 'Idea B', 'PSO', 'GWO', 'P&O', 'INC'};
s.pal   = pal;
% One test per entry of s.order. startsWith(name, s.order) gives one logical
% for the whole list (true if any entry matches), so it always gave index 1.
s.color = @(name) pal(find(cellfun(@(o) startsWith(name, o), s.order), 1), :);
s.ink   = hex('#0b0b0b');
s.ink2  = hex('#52514e');
s.ref   = hex('#9a9993');        % GMPP reference lines
s.band  = hex('#ecebe6');        % search phase shading
s.grid  = hex('#e4e3de');
s.font  = 'Arial';
s.axes  = @(ax) styleAxes(ax, s);
end

function styleAxes(ax, s)
set(ax, 'FontName', s.font, 'FontSize', 9, 'Box', 'off', 'TickDir', 'out', ...
    'XColor', s.ink2, 'YColor', s.ink2, 'GridColor', s.grid, 'GridAlpha', 1, ...
    'XGrid', 'on', 'YGrid', 'on', 'LineWidth', 0.75, 'Layer', 'top');
ax.Title.Color = s.ink;
ax.Title.FontWeight = 'bold';
ax.Title.FontSize = 10;
end
