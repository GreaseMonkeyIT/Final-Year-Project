function f = plot_run_one(r, gm, st, col, tM, morning)
%PLOT_RUN_ONE Power, voltage, and duty against time for one P&O or INC run.
%   r is one element of R in results/mppt_results.mat. gm(id) returns the
%   sweep result of pattern id. For the winter-morning run (set C), tM and
%   morning give the phase times and patterns. Dashed lines: global peak.
f  = figure('Color', st.bg, 'Position', [100 100 1000 720], 'Visible', 'off');
tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axP = nexttile(tl); hold(axP, 'on');
axV = nexttile(tl); hold(axV, 'on');
axD = nexttile(tl); hold(axD, 'on');

if r.set == 'C'
    Pref = 0;
    for j = 1:numel(morning)
        g = gm(morning{j});
        Pref = max(Pref, g.gmpp(2));
        plot(axP, tM(j:j+1), g.gmpp([2 2]), '--', 'Color', st.ink2, 'LineWidth', 1);
        plot(axV, tM(j:j+1), g.gmpp([1 1]), '--', 'Color', st.ink2, 'LineWidth', 1);
        if j > 1
            xline(axP, tM(j), ':', 'Color', st.ink2); xline(axV, tM(j), ':', 'Color', st.ink2);
            xline(axD, tM(j), ':', 'Color', st.ink2);
        end
    end
    ttl = sprintf('%s: Winter morning', r.algName);
else
    g = gm(r.id);
    Pref = g.gmpp(2);
    yline(axP, g.gmpp(2), '--', 'Color', st.ink2, 'LineWidth', 1);
    yline(axV, g.gmpp(1), '--', 'Color', st.ink2, 'LineWidth', 1);
    ttl = sprintf('%s: %s %s', r.algName, g.id, g.name);
    if r.set ~= 'A'     % The same pattern runs in set A and set B. The start duty tells them apart.
        ttl = sprintf('%s, start duty %.2f', ttl, r.Dstart);
    end
end

sk = r.t > 0.005;
plot(axP, r.t(sk), r.P(sk), 'Color', col, 'LineWidth', 1.25);
plot(axV, r.t(sk), r.V(sk), 'Color', col, 'LineWidth', 1.25);
stairs(axD, r.t(sk), r.D(sk), 'Color', col, 'LineWidth', 1.25);
T = r.t(end);
xlim(axP, [0 T]); xlim(axV, [0 T]); xlim(axD, [0 T]);
ylim(axP, [0 1.15 * max(Pref, max(r.P(sk)))]);
ylabel(axP, 'Array power [W]'); ylabel(axV, 'Array voltage [V]'); ylabel(axD, 'Duty');
xlabel(axD, 'Time [s]');
title(axP, ttl);
st.axes(axP); st.axes(axV); st.axes(axD);
end
