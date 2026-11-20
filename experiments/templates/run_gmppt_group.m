%RUN_GMPPT_GROUP Global searches when single bypass-diode groups are shaded.
%
%   Task T6 of HANDOFF_ideas_B_C.md. In MPPT_4x4.slx each panel has one
%   irradiance, so its three groups switch together. The static
%   cross-check showed that the 0.8 Voc methods and DIRECT miss more often
%   when single groups are shaded. This script shows B and C on such
%   patterns in Simulink.
%
%   1. PV4x4_sweep_grp.slx sweeps each pattern of shading_patterns_grp.m.
%      The curves, peaks and GMPP go to results/pv4x4_sweeps_grp.mat.
%   2. gmppt_static_run.m predicts each search on the static curve, with
%      the converter of the model, R_in = (R (1 - D)^2 + RL) / D^2.
%   3. MPPT_4x4_grp.slx runs P&O (mppt.alg = 1), DIRECT (3), Idea B (4)
%      and Idea C (5) on each pattern from start-up, with no change of the
%      shading.
%
%   Outputs in the folder "results":
%     pv4x4_sweeps_grp.mat
%     gmppt_group.mat, gmppt_group.csv
%     fig_grp_patterns.png   irradiance of each group and the P-V curve
%     fig_grp_time.png       power against time, every pattern
%
%   Make the models first, in the project folder (close them first if
%   they are open):
%     build_pv4x4_sweep(true)    % in the folder build, or addpath('build')
%     build_mppt_4x4(true)
%   Run time: about 6 min.

clear; clc;
projectDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % This script is in <project>/experiments/templates
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
resDir = fullfile(projectDir, 'results');
cfg  = pv4x4_config();
p0   = cfg.mppt;
cv   = cfg.conv;
st   = plot_style();
pats = shading_patterns_grp();
algs    = [1 3 4 5];
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C'};
algCol  = st.series([1 2 3 7 8], :);   % As run_gmppt_demo.m
Tstop   = 2.5;

%% 1. Sweeps (as run_pv4x4_sweeps.m)
mdlS = 'PV4x4_sweep_grp';
load_system(fullfile(projectDir, 'models', [mdlS '.slx']));
nP = numel(pats);
in(1:nP) = Simulink.SimulationInput(mdlS);
for k = 1:nP
    in(k) = in(k).setVariable('G', pats(k).G, 'Workspace', mdlS);
end
out = sim(in, 'ShowProgress', 'off');
res = struct('id', {}, 'name', {}, 'G', {}, 'cause', {}, 'V', {}, 'I', {}, 'P', {}, ...
             'Voc', {}, 'Isc', {}, 'peaks', {}, 'gmpp', {});
for k = 1:nP
    V = out(k).Vpv.Data; I = out(k).Ipv.Data; P = out(k).Ppv.Data;
    keep = I > 0;
    V = V(keep); I = I(keep); P = P(keep);
    pk = find(islocalmax(P, 'MinProminence', 0.002 * max(P)));
    [~, j] = max(P);
    res(k) = struct('id', pats(k).id, 'name', pats(k).name, 'G', pats(k).G, 'cause', pats(k).cause, ...
                    'V', V, 'I', I, 'P', P, 'Voc', V(end), 'Isc', I(1), 'peaks', [V(pk) P(pk)], ...
                    'gmpp', [V(j) P(j)]);
    fprintf('%s %-32s %d peaks, GMPP %4.0f W at %5.1f V\n', res(k).id, res(k).name, numel(pk), ...
            res(k).gmpp(2), res(k).gmpp(1));
end
save(fullfile(resDir, 'pv4x4_sweeps_grp.mat'), 'res', 'cfg');
ids = {res.id};
gm  = @(id) res(strcmp(ids, id));

%% 2. Static prediction with the converter of the model
rinRL = @(D) (cv.Rload * (1 - D)^2 + cv.RL) / D^2;
pred = struct();
for a = algs(algs >= 3)
    for k = 1:nP
        p = p0; p.alg = a;
        pred(a, k).r = gmppt_static_run(res(k), p, rinRL, 60);
    end
end

%% 3. Simulink runs from start-up
mdl = 'MPPT_4x4_grp';
load_system(fullfile(projectDir, 'models', [mdl '.slx']));
in = Simulink.SimulationInput.empty;
runs = struct('alg', {}, 'k', {});
for a = algs
    for k = 1:nP
        m = p0;
        m.alg = a;
        s = Simulink.SimulationInput(mdl);
        s = s.setVariable('mppt',   m, 'Workspace', mdl);
        s = s.setVariable('Gsched', [0 res(k).G(:)'], 'Workspace', mdl);
        s = s.setVariable('Tstop',  Tstop, 'Workspace', mdl);
        in(end+1) = s; %#ok<SAGROW>
        runs(end+1) = struct('alg', a, 'k', k); %#ok<SAGROW>
    end
end
tic;
out = sim(in, 'ShowProgress', 'off');
fprintf('\n%d runs in %.0f s\n\n', numel(in), toc);

R = struct('set', {}, 'id', {}, 'alg', {}, 'algName', {}, 't', {}, 'P', {}, 'V', {}, 'ph', {}, ...
           'nSearch', {}, 'tHand', {}, 'Pend', {}, 'pct', {}, 'eff1s', {}, 'onPeak', {});
rows = struct('alg', {});
fprintf('%-7s %-3s %7s %7s %8s %8s %8s %7s  %s\n', 'Alg', 'Pat', 'Probes', 'Static', 'tHand', 'P end', ...
        '% GMPP', '1 s %', 'Stops on');
for q = 1:numel(runs)
    o = out(q);
    a = runs(q).alg;
    g = res(runs(q).k);
    r = struct('set', 'A', 'id', g.id, 'alg', a, 'algName', algName{a}, 't', o.Ppv.Time, ...
               'P', squeeze(o.Ppv.Data), 'V', squeeze(o.Vpv.Data), 'ph', squeeze(o.ph.Data), ...
               'nSearch', 0, 'tHand', NaN, 'Pend', NaN, 'pct', NaN, 'eff1s', NaN, 'onPeak', '');
    np = squeeze(o.np.Data);
    kh = find(r.ph == 2, 1);
    r.tHand = r.t(kh);
    r.nSearch = max([0; np(1:kh)]);
    last = r.t > Tstop - 0.3;
    r.Pend = mean(r.P(last));
    r.pct = 100 * r.Pend / g.gmpp(2);
    r.eff1s = 100 * mean(r.P(r.t <= 1)) / g.gmpp(2);
    [~, j] = min(abs(g.peaks(:,1) - mean(r.V(last))));
    if abs(g.peaks(j,1) - g.gmpp(1)) < 0.5, r.onPeak = 'global';
    else, r.onPeak = sprintf('local, %.1f V', g.peaks(j,1)); end
    R(q) = r;
    nStat = NaN;
    if a >= 3, nStat = pred(a, runs(q).k).r.nSearch; end
    fprintf('%-7s %-3s %7d %7d %6.3f s %6.0f W %8.1f %7.1f  %s\n', r.algName, r.id, r.nSearch, nStat, ...
            r.tHand, r.Pend, r.pct, r.eff1s, r.onPeak);
    w = numel(rows) + 1;
    rows(w).alg = string(r.algName); rows(w).pattern = string(r.id); rows(w).search_probes = r.nSearch;
    rows(w).static_probes = nStat; rows(w).t_handover_s = r.tHand; rows(w).P_end_W = r.Pend;
    rows(w).P_gmpp_W = g.gmpp(2); rows(w).pct_of_gmpp = r.pct; rows(w).pct_first_1s = r.eff1s;
    rows(w).stops_on = string(r.onPeak);
end
T = struct2table(rows(:));
writetable(T, fullfile(resDir, 'gmppt_group.csv'));
save(fullfile(resDir, 'gmppt_group.mat'), 'R', 'T', 'res', 'pred', 'cfg');

%% Figures
exportgraphics(plot_grp_curves(res, st), fullfile(resDir, 'fig_grp_patterns.png'), 'Resolution', 200);
exportgraphics(plot_gmppt_time(R, ids, algs, algName, algCol, gm, st), ...
               fullfile(resDir, 'fig_grp_time.png'), 'Resolution', 200);
close all
fprintf('\nSaved results in %s\n', resDir);
