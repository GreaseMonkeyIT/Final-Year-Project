function fig = fr_traces_dyn(resDir, which)
%FR_TRACES_DYN Power against time of all variants on a cloud event or a ramp.
%   which = 'cloud' (trace B of run_final_traces.m) or 'ramp' (trace C).
%   Each panel: the power of one variant and the GMPP power (grey).
if nargin < 2, which = 'cloud'; end
s = fr_style(); T = load(fullfile(resDir, 'final_traces.mat'), 'B', 'C');
if strcmp(which, 'cloud')
    X = T.B; ttl = sprintf('Cloud event %d of phase 3 (largest change), static bench, sensors on', X.event);
else
    X = T.C; ttl = 'EN 50530 ramp, P0, 30 % to 100 % at 50 W/m^2/s, static bench, sensors on';
end
fig = figure('Color', 'w', 'Position', [100 100 900 720]);
tl = tiledlayout(fig, ceil(numel(X.name) / 2), 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for v = 1:numel(X.name)
    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, X.t, X.Pr / 1000, 'Color', s.ref, 'LineWidth', 2);
    plot(ax, X.t, X.P(:, v) / 1000, 'Color', s.color(X.name{v}), 'LineWidth', 1);
    eta = 100 * sum(X.P(:, v)) / sum(X.Pr);
    title(ax, sprintf('%s: %.2f %%', X.name{v}, eta));
    xlim(ax, [0 X.t(end)]); s.axes(ax);
    ylabel(ax, 'Power (kW)');
    if v > numel(X.name) - 2, xlabel(ax, 'Time (s)'); end
end
title(tl, [ttl '. Grey: GMPP power'], 'FontSize', 10, 'Color', s.ink2);
end
