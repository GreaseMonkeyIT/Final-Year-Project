function f = plot_settling(T, step, p, st, tolPct)
%PLOT_SETTLING Settling of the search probes (fig_settling.png, run_settling_check.m).
%   Left: array voltage after the duty jump of the worst probe, from a
%   settled start. The shaded bands are the averaging windows of the
%   P&O timing (20 ms, last half) and of the search timing (p.Tsearch,
%   last p.Navg_s samples).
%   Right: power error of every probe against the size of its duty jump,
%   for the two timings, with the pass limit tolPct.
f  = figure('Color', st.bg, 'Position', [100 100 1100 460], 'Visible', 'off');
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax = nexttile(tl); hold(ax, 'on');
tms = 1e3 * step.t;
yl  = [0.8 * min(step.V), 1.05 * max(step.V)];
wP  = [1e3 * p.Tmppt / 2, 1e3 * p.Tmppt];
wS  = [1e3 * (p.Nper_s - p.Navg_s) * p.Tc, 1e3 * p.Tsearch];
patch(ax, wP([1 2 2 1]), yl([1 1 2 2]), st.series(2,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
patch(ax, wS([1 2 2 1]), yl([1 1 2 2]), st.series(3,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
plot(ax, tms, step.V, 'Color', st.series(1,:), 'LineWidth', 1.25);
yline(ax, step.Vset, '--', sprintf('Settled %.1f V', step.Vset), 'Color', st.ink2, 'FontName', st.font, ...
      'FontSize', 8, 'LabelHorizontalAlignment', 'right');
text(ax, mean(wP), yl(2), 'P&O window', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
     'FontName', st.font, 'FontSize', 8, 'Color', st.ink);
text(ax, mean(wS), yl(2), 'Search window', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
     'FontName', st.font, 'FontSize', 8, 'Color', st.ink);
xlim(ax, [0 tms(end)]); ylim(ax, yl);
xlabel(ax, 'Time after the duty jump [ms]'); ylabel(ax, 'Array voltage [V]');
title(ax, sprintf('%s on %s, probe %d: duty jump %+.3f to D = %.4f', step.method, step.pattern, ...
      step.probe, step.dD, step.D));
st.axes(ax);

ax = nexttile(tl); hold(ax, 'on');
floorPct = 1e-3;                                 % Errors below this show on the floor of the log axis
x = abs(T.dD);
h1 = plot(ax, x, max(abs(T.err_P_20ms_half_pct), floorPct), 'o', 'Color', st.series(2,:), ...
          'MarkerSize', 5, 'LineWidth', 1);
h2 = plot(ax, x, max(abs(T.err_P_search_pct), floorPct), 'o', 'Color', st.series(3,:), ...
          'MarkerFaceColor', st.series(3,:), 'MarkerSize', 4);
yline(ax, tolPct, '--', sprintf('Limit %.1f %%', tolPct), 'Color', st.ink2, 'FontName', st.font, 'FontSize', 8);
set(ax, 'YScale', 'log');
ylim(ax, [floorPct 10]);
xlabel(ax, 'Duty jump |\DeltaD| into the probe'); ylabel(ax, '|Power error| [% of settled]');
title(ax, 'Error of every probe, five search sequences');
legend(ax, [h1 h2], {sprintf('%g ms, last half', 1e3 * p.Tmppt), ...
       sprintf('%g ms, last %g ms', 1e3 * p.Tsearch, 1e3 * p.Navg_s * p.Tc)}, ...
       'Location', 'northwest', 'Box', 'off', 'FontName', st.font, 'FontSize', 8);
st.axes(ax);
end
