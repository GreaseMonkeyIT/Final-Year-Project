%RUN_FINAL_P3 Phase 3 of the final tests: cloud-edge events from the Oahu fit.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 6). 40
%   events of cloud_events.m (seed 11), each with its own window (10 s to
%   40 s). Each event starts with the light or the shade of its first
%   state, so the controller makes its start-up search first. The edge
%   reaches the array after 4 s.
%   Variants: the five searches with the parabolic stage, and DIRECT with
%   the local stages 1 (P&O), 2 (variable-step INC) and 4 (INC). The
%   controller values of pv4x4_config.m, with T_rescan = 0 (the windows
%   are short). 25 degC, sensors on (sens_draw.m).
%   Part A: MPPT_4x4_grp.slx. Part B: the static bench with the same
%   events (curves every 0.05 s), with the sensors on and off.
%   Values of each event, from t = 3 s to the end:
%     eta       energy over the energy of the GMPP [%]
%     nSrch     searches that start after 3 s
%     wrongEnd  the run ends on a wrong peak
%     tStable   time [s] after which the GMPP power changes by less than
%               0.1 % in each step of 0.05 s of the curve bank (the light
%               is steady again)
%     tRec      recovery time [s]: from tStable to the first time after
%               which the power stays at 99 % of the GMPP or more until the
%               end. NaN: no recovery before the end of the window.
%     Lsearch   energy lost during the searches [% of the GMPP energy]
%   Changed on 2026-11-22: tStable and tRec replace the values "moved",
%   "missed" and "false" of the first version. The first version found no
%   moved global peak in the 40 events (its voltage test compared only the
%   first and the last curve), so those values gave no information.
%
%   Outputs in the folder "results": final_p3.mat, final_p3.csv,
%   final_p3.txt. Run experiments/oahu_fit.m and build/build_static_mex.m first.
%   FINAL_QUICK set in the environment: a smoke test with a few cases,
%   outputs in results/quick.
%   FINAL_INC set in the environment: only the variants with an INC
%   (local stages 2 and 4, p.alg = 2), outputs final_<phase>_inc.*. Added
%   on 2026-11-22 for the rerun after the fix of the INC hold.


clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
if isfile(fullfile(projectDir, 'results', 'STOP'))      % Pause of the final tests: skip this phase
    fprintf('results/STOP exists: phase skipped\n'); return
end
resDir = fullfile(projectDir, 'results');
resIn = resDir;
quick = ~isempty(getenv('FINAL_QUICK'));   % Smoke test: few cases, outputs in results/quick
if quick, resDir = fullfile(resDir, 'quick'); if ~isfolder(resDir), mkdir(resDir); end, end
incOnly = ~isempty(getenv('FINAL_INC'));   % Rerun of the INC variants only (fix of 2026-11-22),
sfx = ''; if incOnly, sfx = '_inc'; end    % outputs final_<phase>_inc.*
cfg = pv4x4_config();
logf = fopen(fullfile(resDir, ['final_p3' sfx '.txt']), 'w');
say(logf, 'run_final_p3.m, %s\n', char(datetime('now')));
F  = load(fullfile(resIn, 'oahu_fit.mat'));
ev = cloud_events(F.fit, 40 - 38 * quick, 11);
say(logf, '%d events: windows %.1f to %.1f s, total %.0f s\n', numel(ev), min(arrayfun(@(e) e.t(end), ev)), ...
    max(arrayfun(@(e) e.t(end), ev)), sum(arrayfun(@(e) e.t(end), ev)));
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
locName = {'P&O', 'VS-INC', 'Parabolic', 'INC'};
var = final_variants();                    % Final comparison (2026-11-23), final_variant.m
if quick, var = var([1 3]); end
if incOnly, var = var([var.loc] == 2 | [var.loc] == 4); end
vname = @final_vname;
nE = numel(ev); nV = numel(var);

%% Curves of each event (every 0.05 s)
sim_pool(4);
bank = cell(1, nE);
t0 = tic;
for e = 1:nE
    tb = ev(e).t(1:5:end)'; Gt = ev(e).G(1:5:end, :);
    I = zeros(4000, numel(tb)); Pg = zeros(1, numel(tb)); Vgm = Pg; pk = cell(1, numel(tb));
    parfor j = 1:numel(tb)
        b = bench_curve(reshape(Gt(j, :), 12, 4), 25, cfg); %#ok<PFBNS>
        I(:, j) = b.I; Pg(j) = b.gmpp(2); Vgm(j) = b.gmpp(1); pk{j} = b.peaks;
    end
    bank{e} = struct('Vg', linspace(0, 200, 4000)', 'I', I, 'Pg', Pg, 'Vgm', Vgm, 'tb', tb, 'pk', {pk});
end
say(logf, 'Curves: %.0f s\n', toc(t0));

%% Part A: Simulink
runs = struct('mppt', {}, 'Gsched', {}, 'Tstop', {}, 'T', {}, 'sens', {});
key = zeros(0, 2);
for e = 1:nE
    for v = 1:nV
        m = final_variant(cfg.mppt, var(v)); m.T_rescan = 0; m.rng_seed = 1001;
        runs(end+1) = struct('mppt', m, 'Gsched', [ev(e).t ev(e).G], 'Tstop', ev(e).t(end), 'T', 25, ...
                             'sens', sens_draw(cfg.sens, 300 + e)); %#ok<SAGROW>
        key(end+1, :) = [e v]; %#ok<SAGROW>
    end
end
[out, info] = bench_sim('MPPT_4x4_grp', runs, projectDir);
say(logf, 'Part A: %d runs, %.0f s simulated, %.0f s wall, MATLAB RAM %.1f GiB\n', numel(runs), info.simSeconds, ...
    info.wall, info.ramGiB);
RA = nan(numel(runs), 6);                  % [eta, nSrch, wrongEnd, tStable, tRec, Lsearch]
for k = 1:numel(runs)
    o = out(k); e = key(k, 1);
    if ~isempty(o.ErrorMessage), say(logf, 'Run %d: %s\n', k, o.ErrorMessage); continue, end
    t = o.Ppv.Time; P = o.Ppv.Data; V = o.Vpv.Data;
    ph = interp1(o.ph.Time, squeeze(o.ph.Data), t, 'previous', 'extrap');
    RA(k, :) = eventValues(t, V, P, ph, bank{e});
end

%% Part B: static bench, sensors on and off
rinA = [cfg.conv.Rload cfg.conv.RL];
RB = nan(numel(runs), 6, 2);
keyB = key;
for nz = 1:2
    tmp = nan(numel(runs), 6);
    parfor k = 1:numel(runs)
        e = keyB(k, 1); b = bank{e}; r = runs(k); %#ok<PFBNS>
        s = r.sens; if nz == 2, s = cfg.sens; end %#ok<PFBNS>
        [Pl, Vl, ~, phl] = static_run_mex(b.Vg, b.I, b.Pg, b.tb, b.tb, b.tb, 0.005, r.Tstop, 40, rinA, r.mppt, s);
        t = (1:numel(Pl))' * 2e-3;
        tmp(k, :) = eventValues(t, Vl, Pl, phl, b);
    end
    RB(:, :, nz) = tmp;
end

%% Table
fid = fopen(fullfile(resDir, ['final_p3' sfx '.csv']), 'w');
fprintf(fid, 'event,variant,speed_m_s,dir_deg,width_m,kt_low,kt_high,sense,window_s,eta_sim,searches_sim,wrong_end_sim,t_stable_s,t_recovery_sim_s,search_loss_sim_pct,eta_static_on,t_recovery_static_on_s,eta_static_off\n');
for k = 1:numel(runs)
    e = key(k, 1); x = ev(e);
    fprintf(fid, '%d,%s,%.2f,%.0f,%.1f,%.3f,%.3f,%d,%.1f,%.3f,%d,%d,%.3f,%.3f,%.4f,%.3f,%.3f,%.3f\n', e, vname(var(key(k, 2))), x.v, ...
            x.dir, x.w, x.kLow, x.kHigh, x.sense, x.t(end), RA(k, 1:6), RB(k, 1, 1), RB(k, 5, 1), RB(k, 1, 2));
end
fclose(fid);
say(logf, '\n%-22s %16s %6s %6s %16s %6s %18s\n', 'Variant', 'Eta mean/min', 'Srch', 'Wrong', 'tRec mean/max s', 'NoRec', 'Static on/off mean');
for v = 1:nV
    X = RA(key(:, 2) == v, :); Y1 = RB(key(:, 2) == v, 1, 1); Y2 = RB(key(:, 2) == v, 1, 2);
    ok = ~isnan(X(:, 1));
    say(logf, '%-22s %8.3f/%7.3f %6d %6d %7.3f/%7.3f %6d %9.3f/%8.3f\n', vname(var(v)), mean(X(ok, 1)), ...
        min(X(ok, 1)), sum(X(ok, 2)), sum(X(ok, 3)), mean(X(ok, 5), 'omitnan'), max(X(ok, 5)), ...
        sum(isnan(X(ok, 5))), mean(Y1), mean(Y2));
end
save(fullfile(resDir, ['final_p3' sfx '.mat']), 'ev', 'var', 'key', 'RA', 'RB', 'info');
fclose(logf);

%% Local functions
function x = eventValues(t, V, P, ph, b)
% Values of one event from t = 3 s (see the help text).
use = t >= 3;
ic  = min(max(round(interp1(b.tb, 1:numel(b.tb), t, 'linear', 'extrap')), 1), numel(b.tb));
Pg  = b.Pg(ic)'; P = P(:); V = V(:); ph = ph(:);
eta = 100 * sum(P(use)) / sum(Pg(use));
ks  = find(ph == 1 & [true; ph(1:end-1) ~= 1] & use);
cE  = b.pk{end}; [~, ig] = max(cE(:, 2)); last = t > t(end) - 0.3;
[~, in] = min(abs(mean(V(last)) - cE(:, 1)));
wrongEnd = size(cE, 1) > 1 && in ~= ig;
% The light is steady after the last step of the bank with a change of
% more than 0.1 % of the GMPP power.
dPg = abs(diff(b.Pg)) ./ b.Pg(1:end-1);
js  = find(dPg > 1e-3, 1, 'last');
tSt = 3;
if ~isempty(js), tSt = max(3, b.tb(js + 1)); end
% Recovery: the first time after tSt from which P / Pg >= 0.99 to the end.
low = find(P ./ Pg < 0.99 & t >= tSt, 1, 'last');
if isempty(low)
    tRec = 0;
elseif low < numel(t)
    tRec = t(low + 1) - tSt;
else
    tRec = NaN;                            % Not recovered before the end of the window
end
Ls = 100 * sum(Pg(use & ph == 1) - P(use & ph == 1)) / sum(Pg(use));
x = [eta, numel(ks), wrongEnd, tSt, tRec, Ls];
end

function say(fid, varargin)
fprintf(varargin{:});
fprintf(fid, varargin{:});
end
