function fig = fr_en50530(resDir)
%FR_EN50530 Dynamic MPPT efficiency on the EN 50530 ramps (phase 2, part A, 25 degC).
s = fr_style(); X = load(fullfile(resDir, 'final_p2.mat'), 'jobs', 'resA', 'var', 'seqs', 'pid');
fig = figure('Color', 'w', 'Position', [100 100 1000 620]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for ip = 1:2
    for q = 1:2
        ax = nexttile(tl); hold(ax, 'on');
        for v = 1:numel(X.var)
            nm = final_vname(X.var(v));
            m = X.jobs(:, 1) == v & X.jobs(:, 2) == ip & X.jobs(:, 3) == 1 & X.jobs(:, 4) == q;
            rw = X.jobs(m, 5); sl = X.seqs(q).rows(rw, 1);
            [sl, o] = sort(sl); e = X.resA(m, 1); e = e(o);
            plot(ax, sl, e, '-o', 'Color', s.color(nm), 'MarkerFaceColor', s.color(nm), 'MarkerSize', 4, 'LineWidth', 1.2);
        end
        set(ax, 'XScale', 'log'); s.axes(ax);
        title(ax, sprintf('%s, ramps %s %% of 1000 W/m^2', X.pid{ip}, X.seqs(q).name));
        if ip == 2, xlabel(ax, 'Ramp slope (W/m^2/s)'); end
        if q == 1, ylabel(ax, 'Dynamic efficiency (%)'); end
        if ip == 1 && q == 2
            legend(ax, arrayfun(@final_vname, X.var, 'UniformOutput', false), 'Location', 'southwest', ...
                   'Box', 'off', 'FontSize', 8);
        end
    end
end
title(tl, 'EN 50530 ramp test, static bench, sensors on, 25 °C', 'FontSize', 10, 'Color', s.ink2);
end
