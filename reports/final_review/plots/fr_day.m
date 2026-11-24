function fig = fr_day(resDir)
%FR_DAY One full day (trace D) and the energy ratio of all days (phase 4, T_rescan = 900 s).
s = fr_style(); T = load(fullfile(resDir, 'final_traces.mat'), 'D'); D = T.D;
X = load(fullfile(resDir, 'final_p4.mat'), 'res', 'job', 'var', 'D');
fig = figure('Color', 'w', 'Position', [100 100 1000 380]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');
ax = nexttile(tl); hold(ax, 'on');
if isfield(D, 'P')
    plot(ax, D.t_h, D.Pr / 1000, 'Color', s.ref, 'LineWidth', 2);
    plot(ax, D.t_h, D.P(:, 1) / 1000, 'Color', s.color(D.names{1}), 'LineWidth', 0.8);
    title(ax, sprintf('%s, day %s: %.3f %% of the GMPP energy', D.names{1}, D.day, 100 * sum(D.P(:, 1)) / sum(D.Pr)));
end
s.axes(ax); xlabel(ax, 'Hour of the day'); ylabel(ax, 'Power (kW)');
ax = nexttile(tl); hold(ax, 'on');
v9 = find([X.var.Tr] == 900); scen = {'open', 'morning'};
for i = 1:numel(v9)
    v = v9(i); nm = final_vname(X.var(v));
    for sc = 1:2
        m = X.job(:, 2) == v & strcmp({X.D(X.job(:, 1)).scen}', scen{sc});
        r = 100 * sum(X.res(m, 1)) / sum(X.res(m, 2));
        b = bar(ax, i + 0.2 * (2 * sc - 3), r, 0.38, 'FaceColor', s.color(nm), 'EdgeColor', 'none');
        if sc == 2, b.FaceAlpha = 0.55; end
        % Vertical labels: two bars side by side leave no room for horizontal ones.
        text(ax, i + 0.2 * (2 * sc - 3), r + 0.01, sprintf('%.2f', r), 'HorizontalAlignment', 'left', ...
             'VerticalAlignment', 'middle', 'Rotation', 90, 'FontSize', 7, 'Color', s.ink);
    end
end
set(ax, 'XTick', 1:numel(v9), 'XTickLabel', strtok(arrayfun(@final_vname, X.var(v9), 'UniformOutput', false), '+'));
ylim(ax, [99 100.2]); s.axes(ax); ylabel(ax, 'Energy / GMPP energy, 4 days (%)');
title(ax, 'Phase 4, T_{rescan} = 900 s. Dark: open sky, light: morning shade');
end
