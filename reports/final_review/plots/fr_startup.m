function fig = fr_startup(resDir, pat)
%FR_STARTUP Simulink start-up waveforms of all variants on one pattern.
%   Power over the GMPP power against time. Grey band: search phase.
if nargin < 2, pat = 'R1'; end
s = fr_style(); T = load(fullfile(resDir, 'final_traces.mat'), 'S');
S = T.S(strcmp({T.S.pat}, pat));
fig = figure('Color', 'w', 'Position', [100 100 900 720]);
tl = tiledlayout(fig, ceil(numel(S) / 2), 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:numel(S)
    r = S(k); ax = nexttile(tl); hold(ax, 'on');
    y = 100 * r.P / r.gmpp(2);
    srch = r.ph == 1;
    if any(srch)
        ts = r.t(find(srch, 1)); te = r.t(find(srch, 1, 'last'));
        patch(ax, [ts te te ts], [0 0 105 105], s.band, 'EdgeColor', 'none');
    end
    yline(ax, 100, '--', 'Color', s.ref);
    plot(ax, r.t, y, 'Color', s.color(r.name), 'LineWidth', 1.2);
    title(ax, sprintf('%s: %.2f %% at 4 s', r.name, mean(y(r.t > 3.7))));
    xlim(ax, [0 4]); ylim(ax, [0 105]); s.axes(ax);
    ylabel(ax, 'P / P_{GMPP} (%)');
    if k > numel(S) - 2, xlabel(ax, 'Time (s)'); end
end
title(tl, sprintf('Start-up on pattern %s, Simulink, sensors on. Grey: global search', pat), ...
      'FontSize', 10, 'Color', s.ink2);
end
