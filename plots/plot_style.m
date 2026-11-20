function s = plot_style()
%PLOT_STYLE Colors and axes settings for the figures of the 4 x 4 study.
%
%   s = plot_style() returns the colors as RGB rows and a function that
%   formats an axes: s.axes(ax).
%
%   The series colors are the eight slots of a validated categorical
%   palette. Use them in this order. Three of them (aqua, yellow, and
%   magenta) have low contrast on white, so each line also gets a text
%   label. For more than eight series, draw one series as the reference in
%   s.ink2 (the plots use this for the uniform pattern P0).

hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;

s.series = [hex('#2a78d6'); hex('#eb6834'); hex('#1baf7a'); hex('#eda100'); ...
            hex('#e87ba4'); hex('#008300'); hex('#4a3aa7'); hex('#e34948')];
s.ink    = hex('#0b0b0b');   % Titles and values
s.ink2   = hex('#52514e');   % Axis labels and notes
s.ref    = hex('#b9b8b2');   % Reference curves (uniform irradiance)
s.grid   = hex('#e4e3de');
s.bg     = [1 1 1];
% Sequential ramp for irradiance (one hue, light to dark = low to high).
s.seq    = [hex('#cde2fb'); hex('#9ec5f4'); hex('#6da7ec'); hex('#3987e5'); ...
            hex('#256abf'); hex('#184f95'); hex('#0d366b')];
s.font   = 'Arial';
s.axes   = @(ax) styleAxes(ax, s);
end

function styleAxes(ax, s)
set(ax, 'FontName', s.font, 'FontSize', 9, 'Box', 'off', 'TickDir', 'out', ...
    'XColor', s.ink2, 'YColor', s.ink2, 'GridColor', s.grid, 'GridAlpha', 1, ...
    'XGrid', 'on', 'YGrid', 'on', 'LineWidth', 0.75, 'Layer', 'bottom');
ax.Title.Color = s.ink;
ax.Title.FontWeight = 'bold';
ax.Title.FontSize = 10;
end
