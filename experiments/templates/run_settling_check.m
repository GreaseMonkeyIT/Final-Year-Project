%RUN_SETTLING_CHECK Check that each search probe settles before the tracker uses it.
%
%   The ceiling V1 x I2 of Ideas B and C holds only if each probe is in
%   steady state. The settling check of run_po_demo.m covers P&O steps of
%   0.005 in duty. The searches of DIRECT, Idea B and Idea C jump by up
%   to 0.32 in duty (DIRECT, from 0.38 to 0.70). This script checks those
%   jumps in MPPT_4x4.slx (task T1 of HANDOFF_ideas_B_C.md).
%
%   Method:
%   1. The duty sequences come from crosscheck/simulink_curves_runs.json,
%      made by "python run_simulink_curves.py" in the folder crosscheck.
%      Each sequence has the search probes of one case and the first nPO
%      probes of the P&O stage after the hand-over.
%   2. Fast runs. The controller replays the sequence (mppt.alg = 9). Each
%      entry holds for H MPPT periods, so one probe lasts H x mppt.Tmppt.
%      H = 1 is the P&O timing (20 ms). H = mppt.Tsearch / mppt.Tmppt is
%      the timing of the search probes (40 ms).
%   3. Slow run. Each entry holds for Nslow periods. The second half of the
%      last period of each hold gives the settled value at that duty.
%   4. For each probe, the script compares the average over the end of
%      the fast probe with the settled value. It uses two windows: the
%      last half and the last quarter of the probe. The check passes if
%      every power error of the search timing (mppt.Tsearch, last
%      mppt.Navg_s samples) is below tolPct of the settled power.
%   The script also gives the static point of the sweep curve at each
%   duty. The static point uses the ideal converter,
%   R_in = R (1 - D)^2 / D^2, as in crosscheck/algos.py, and also the
%   converter with the inductor resistance RL,
%   R_in = (R (1 - D)^2 + RL) / D^2.
%
%   Outputs in the folder results:
%     settling_check.csv, settling_check.mat   one row for each probe
%     fig_settling.png                          the step response of the
%                                               worst probe, and the error
%                                               of every probe against the
%                                               duty jump
%
%   Run scripts/build_mppt_4x4.m and run_pv4x4_sweeps.m first.
%   Run time: about 7 min.

clear; clc;
projectDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % This script is in <project>/experiments/templates
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
resDir = fullfile(projectDir, 'results');
S   = load(fullfile(resDir, 'pv4x4_sweeps.mat'));
sw  = S.res;
ids = {sw.id};
gm  = @(id) sw(strcmp(ids, id));
cfg = pv4x4_config();
p0  = cfg.mppt;
cv  = cfg.conv;
st  = plot_style();
mdl = 'MPPT_4x4';
load_system(fullfile(projectDir, 'models', [mdl '.slx']));

%% Cases: {method in the JSON file, pattern}
cases = {'DIRECT', 'P1'
         'DIRECT', 'R1'
         'Idea B', 'R1'
         'Idea C', 'P1'
         'Idea C', 'R1'};
nPO    = 10;     % P&O probes after the hand-over
Nslow  = 5;      % Periods for each entry in the slow run
tolPct = 0.5;    % Pass limit [% of the settled power]
Hs     = round(p0.Nper_s / p0.Nper);   % Search probe in MPPT periods
assert(Hs * p0.Nper == p0.Nper_s, 'mppt.Tsearch must be a whole number of MPPT periods.');
Hfast  = unique([1 Hs]);
holds  = [Hfast Nslow];

J = jsondecode(fileread(fullfile(projectDir, 'archive', '2026-11-21_post_midreview', 'python', 'simulink_curves_runs.json')));
nC  = size(cases, 1);
seq = cell(nC, 1);
nS  = zeros(nC, 1);
for c = 1:nC
    r = J.(matlab.lang.makeValidName(cases{c,1})).(cases{c,2});
    nS(c)  = r.summary.glob;
    seq{c} = [r.log(1:nS(c) + nPO).D];
end

%% Simulation inputs: the fast runs and the slow run of each case
in = Simulink.SimulationInput.empty;
for c = 1:nC
    N = numel(seq{c});
    for H = holds
        m = p0;
        m.alg   = 9;
        m.Drep(1:N) = seq{c};
        m.Nrep  = N;
        m.Nhold = H;
        s = Simulink.SimulationInput(mdl);
        s = s.setVariable('mppt',   m, 'Workspace', mdl);
        s = s.setVariable('Gsched', [0 gm(cases{c,2}).G(:)'], 'Workspace', mdl);
        s = s.setVariable('Tstop',  (p0.Nwait + N * H + 1) * p0.Tmppt, 'Workspace', mdl);
        s = s.setVariable('Tlog',   p0.Tc, 'Workspace', mdl);   % Log every control sample
        in(end+1) = s; %#ok<SAGROW>
    end
end
tic;
out = reshape(sim(in, 'ShowProgress', 'off'), numel(holds), nC);
fprintf('%d runs in %.0f s\n', numel(in), toc);

%% Results: one row for each probe
Nper = p0.Nper;
T = table();
step = struct('err', 0);           % Step response of the worst probe (20 ms, last half)
for c = 1:nC
    g  = gm(cases{c,2});
    [Vs, Is] = samples(out(end, c), p0.Tc);
    Vf = cell(numel(Hfast), 1);
    If = cell(numel(Hfast), 1);
    for h = 1:numel(Hfast)
        [Vf{h}, If{h}] = samples(out(h, c), p0.Tc);
    end
    D  = seq{c}(:);
    N  = numel(D);
    Dprev = [p0.Dstart; D(1:end-1)];
    row = struct();
    for j = 1:N
        eS = (p0.Nwait + j * Nslow) * Nper;          % Last sample of entry j in the slow run
        [vs, is]   = avg(Vs, Is, eS, Nper / 2);
        [vs1, is1] = avg(Vs, Is, eS - Nper, Nper / 2);
        Rid = cv.Rload * (1 - D(j))^2 / D(j)^2;
        Rrl = (cv.Rload * (1 - D(j))^2 + cv.RL) / D(j)^2;
        [vi, ii] = pv_static_point(g.V, g.I, Rid);
        [vr, ir] = pv_static_point(g.V, g.I, Rrl);
        row(j).method    = string(cases{c,1});
        row(j).pattern   = string(cases{c,2});
        row(j).probe     = j;
        row(j).stage     = string(ifelse(j <= nS(c), 'search', 'P&O'));
        row(j).D         = D(j);
        row(j).dD        = D(j) - Dprev(j);
        row(j).V_settled = vs;
        row(j).P_settled = vs * is;
        for h = 1:numel(Hfast)
            H  = Hfast(h);
            eF = (p0.Nwait + j * H) * Nper;          % Last sample of probe j in this fast run
            tag = sprintf('%dms', round(1e3 * H * p0.Tmppt));
            [v2, i2] = avg(Vf{h}, If{h}, eF, H * Nper / 2);
            [v4, i4] = avg(Vf{h}, If{h}, eF, H * Nper / 4);
            row(j).(['err_P_' tag '_half_pct'])    = 100 * (v2 * i2 - vs * is) / (vs * is);
            row(j).(['err_P_' tag '_quarter_pct']) = 100 * (v4 * i4 - vs * is) / (vs * is);
            if H == Hs
                [vw, iw] = avg(Vf{h}, If{h}, eF, p0.Navg_s);
                row(j).err_P_search_pct = 100 * (vw * iw - vs * is) / (vs * is);
                row(j).err_V_search_pct = 100 * (vw - vs) / vs;
                row(j).err_I_search_pct = 100 * (iw - is) / is;
            end
            if H == 1 && abs(row(j).(['err_P_' tag '_half_pct'])) > step.err
                bS = eS - Nslow * Nper;              % Last sample before entry j in the slow run
                k  = bS + (1:min(Nslow, 3) * Nper);
                step = struct('err', abs(row(j).(['err_P_' tag '_half_pct'])), 'method', cases{c,1}, ...
                              'pattern', cases{c,2}, 'probe', j, 'D', D(j), 'dD', D(j) - Dprev(j), ...
                              't', (1:numel(k))' * p0.Tc, 'V', Vs(k), 'Vset', vs);
            end
        end
        row(j).slow_drift_pct = 100 * (vs * is - vs1 * is1) / (vs * is);   % Last two slow periods
        row(j).P_static_ideal = vi * ii;
        row(j).err_static_ideal_pct = 100 * (vs * is - vi * ii) / (vi * ii);
        row(j).P_static_RL = vr * ir;
        row(j).err_static_RL_pct = 100 * (vs * is - vr * ir) / (vr * ir);
    end
    T = [T; struct2table(row(:))]; %#ok<AGROW>
end

%% Table
tS = sprintf('%dms', round(1e3 * p0.Tsearch));
fprintf('\nPower error of each probe against the settled value [%%]\n');
fprintf('%-7s %-3s %3s %-6s %7s %7s %8s %9s %9s %9s %9s %9s\n', 'Method', 'Pat', 'j', 'Stage', 'D', 'dD', ...
        'P set', '20ms half', '20ms qtr', [tS ' half'], [tS ' qtr'], 'stat RL');
for k = 1:height(T)
    r = T(k,:);
    fprintf('%-7s %-3s %3d %-6s %7.4f %+7.3f %6.0f W %+9.3f %+9.3f %+9.3f %+9.3f %+9.3f\n', r.method, ...
            r.pattern, r.probe, r.stage, r.D, r.dD, r.P_settled, r.err_P_20ms_half_pct, ...
            r.err_P_20ms_quarter_pct, r.(['err_P_' tS '_half_pct']), r.(['err_P_' tS '_quarter_pct']), ...
            r.err_static_RL_pct);
end
fprintf('\nLargest |error| [%%] of each case:\n');
fprintf('  %-7s %-3s %9s %9s %9s %9s  %s\n', 'Method', 'Pat', '20ms half', '20ms qtr', [tS ' half'], [tS ' qtr'], 'slow drift');
for c = 1:nC
    sel = T.method == cases{c,1} & T.pattern == cases{c,2};
    fprintf('  %-7s %-3s %9.3f %9.3f %9.3f %9.3f  %.4f\n', cases{c,1}, cases{c,2}, ...
            max(abs(T.err_P_20ms_half_pct(sel))), max(abs(T.err_P_20ms_quarter_pct(sel))), ...
            max(abs(T.(['err_P_' tS '_half_pct'])(sel))), max(abs(T.(['err_P_' tS '_quarter_pct'])(sel))), ...
            max(abs(T.slow_drift_pct(sel))));
end
worst = max(abs(T.err_P_search_pct));
fprintf('\nSearch timing: %g ms probe, average of the last %d samples (%g ms).\n', 1e3 * p0.Tsearch, ...
        p0.Navg_s, 1e3 * p0.Navg_s * p0.Tc);
fprintf('Worst power error: %.3f %% (V %.3f %%, I %.3f %%). Limit %.1f %%: %s\n', worst, ...
        max(abs(T.err_V_search_pct)), max(abs(T.err_I_search_pct)), tolPct, ifelse(worst < tolPct, 'PASS', 'FAIL'));
fprintf('P&O timing (20 ms, last half), P&O probes only: worst %.3f %%\n', ...
        max(abs(T.err_P_20ms_half_pct(T.stage == "P&O"))));
fprintf('Settled power against the static curve: ideal converter %+.2f %% to %+.2f %%, with RL %+.3f %% to %+.3f %%\n', ...
        min(T.err_static_ideal_pct), max(T.err_static_ideal_pct), min(T.err_static_RL_pct), max(T.err_static_RL_pct));

writetable(T, fullfile(resDir, 'settling_check.csv'));
save(fullfile(resDir, 'settling_check.mat'), 'T', 'step', 'cases', 'nPO', 'Nslow', 'cfg');

%% Figure
exportgraphics(plot_settling(T, step, p0, st, tolPct), fullfile(resDir, 'fig_settling.png'), 'Resolution', 200);
close all
fprintf('\nSaved results in %s\n', resDir);

%% Local functions
function [V, I] = samples(o, Tc)
% Logged V and I at every control sample, from t = 0. Log point q is
% control call q (q = 1 at t = 0).
t = o.Vpv.Time(:);
V = squeeze(o.Vpv.Data);
I = squeeze(o.Ipv.Data);
assert(abs(t(1)) < 1e-12 && max(abs(diff(t) - Tc)) < 1e-9, 'The log must have one point for each control sample.');
end

function [v, i] = avg(V, I, qEnd, w)
% Average of V and I over the w samples that end at sample qEnd.
q = qEnd - w + 1 : qEnd;
v = mean(V(q));
i = mean(I(q));
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
