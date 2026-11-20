%CHECK_GMPPT_CONTROLLER Compare the global searches in MPPT_4x4.slx with the static check.
%
%   Task T3 of HANDOFF_ideas_B_C.md. The script runs mppt.alg = 3
%   (DIRECT), 4 (Idea B), 5 (Idea C), 6 (DIRECT as in the paper), 7 (PSO)
%   and 8 (Idea B refined) in MPPT_4x4.slx on each pattern of
%   shading_patterns.m, from start-up, with no change of the shading. For
%   each run it reads the duty of every search probe from the logs ph
%   and np, and compares the sequence with gmppt_static_check.m:
%     'RL'     the static plant with the converter of MPPT_4x4.slx. The
%              sequences must be the same.
%     'ideal'  the static plant of crosscheck/algos.py.
%   It also compares the measured power of each probe (the averages Vm
%   and Im of the controller) with the static point at its duty.
%
%   Outputs in the folder results:
%     gmppt_controller_check.csv, gmppt_controller_check.mat
%
%   Run scripts/build_mppt_4x4.m, run_pv4x4_sweeps.m and
%   gmppt_static_check.m first. Run time: about 12 min.

clear; clc;
projectDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % This script is in <project>/experiments/templates
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
resDir = fullfile(projectDir, 'results');
S   = load(fullfile(resDir, 'pv4x4_sweeps.mat'));
sw  = S.res;
SC  = load(fullfile(resDir, 'gmppt_static_check.mat'));   % R: static runs
cfg = pv4x4_config();
p0  = cfg.mppt;
cv  = cfg.conv;
mdl = 'MPPT_4x4';
load_system(fullfile(projectDir, 'models', [mdl '.slx']));

algs  = [3 4 5 6 7 8];
names = {'DIRECT', 'Idea B', 'Idea C', 'DIRECT paper', 'PSO', 'Idea B refined'};   % alg - 2
nMax  = 36;                                    % Probes that fit in the run (PSO: 33 on these patterns)
Tstop = p0.Nwait * p0.Tmppt + nMax * p0.Tsearch;

%% Runs
in = Simulink.SimulationInput.empty;
runs = struct('alg', {}, 'k', {});
for a = algs
    for k = 1:numel(sw)
        m = p0;
        m.alg = a;
        s = Simulink.SimulationInput(mdl);
        s = s.setVariable('mppt',   m, 'Workspace', mdl);
        s = s.setVariable('Gsched', [0 sw(k).G(:)'], 'Workspace', mdl);
        s = s.setVariable('Tstop',  Tstop, 'Workspace', mdl);
        in(end+1) = s; %#ok<SAGROW>
        runs(end+1) = struct('alg', a, 'k', k); %#ok<SAGROW>
    end
end
tic;
out = sim(in, 'ShowProgress', 'off');
fprintf('%d runs in %.0f s\n\n', numel(in), toc);

%% Compare
fprintf('%-7s %-3s %7s %7s %7s  %-9s %-9s %9s %9s\n', 'Method', 'Pat', 'Simulink', 'RL', 'ideal', ...
        'vs RL', 'vs ideal', 'hand-over', 'max dP %');
rows = struct('method', {});
for r = 1:numel(runs)
    o  = out(r);
    a  = runs(r).alg;
    g  = sw(runs(r).k);
    ph = squeeze(o.ph.Data);
    np = squeeze(o.np.Data);
    Dl = squeeze(o.D.Data);
    tl = o.ph.Time;
    nS = max(np(ph == 1));
    if isempty(nS), nS = 0; end
    Ds = zeros(nS, 1);
    for j = 1:nS
        Ds(j) = Dl(find(ph == 1 & np == j, 1, 'last'));
    end
    kh = find(ph == 2, 1);
    done = ~isempty(kh);
    Dh = NaN;
    if done, Dh = Dl(kh); end
    % Measured power of each probe: Vm and Im at the end of the probe.
    tE = (p0.Nwait + (1:nS)' * round(p0.Tsearch / p0.Tmppt)) * p0.Tmppt;
    tv = o.Vm.Time;
    Vm = squeeze(o.Vm.Data);
    Im = squeeze(o.Im.Data);
    dP = zeros(nS, 1);
    for j = 1:nS
        [~, q] = min(abs(tv - tE(j)));
        [vs, is] = pv_static_point(g.V, g.I, (cv.Rload * (1 - Ds(j))^2 + cv.RL) / Ds(j)^2);
        dP(j) = 100 * (Vm(q) * Im(q) - vs * is) / (vs * is);
    end
    sRL = SC.R(strcmp({SC.R.map}, 'RL')    & [SC.R.alg] == a & strcmp({SC.R.id}, g.id));
    sId = SC.R(strcmp({SC.R.map}, 'ideal') & [SC.R.alg] == a & strcmp({SC.R.id}, g.id));
    [okRL, jRL] = sameSeq(Ds, sRL.D(1:sRL.nSearch));
    nq = min(numel(Ds), sRL.nSearch);
    dDRL = max([0; abs(Ds(1:nq) - sRL.D(1:nq))]);   % Largest duty difference from the RL plant
    [okId, jId] = sameSeq(Ds, sId.D(1:sId.nSearch));
    fprintf('%-7s %-3s %7d %7d %7d  %-9s %-9s %9.4f %9.3f\n', names{a - 2}, g.id, nS, sRL.nSearch, ...
            sId.nSearch, seqText(okRL, jRL), seqText(okId, jId), Dh, max(abs(dP)));
    j = numel(rows) + 1;
    rows(j).method = string(names{a - 2});
    rows(j).pattern = string(g.id);
    rows(j).probes_simulink = nS;
    rows(j).probes_static_RL = sRL.nSearch;
    rows(j).probes_static_ideal = sId.nSearch;
    rows(j).same_as_RL = okRL;
    rows(j).first_diff_RL = jRL;
    rows(j).max_abs_dD_RL = dDRL;
    rows(j).same_as_ideal = okId;
    rows(j).first_diff_ideal = jId;
    rows(j).handover_simulink = Dh;
    rows(j).handover_static_RL = sRL.Dhand;
    rows(j).search_done = done;
    rows(j).max_abs_probe_dP_pct = max(abs(dP));
    rows(j).t_handover = NaN;
    if done, rows(j).t_handover = tl(kh); end
end
T = struct2table(rows(:));
fprintf('\nSame sequence as the static RL plant: %d of %d runs.\n', sum(T.same_as_RL), height(T));
fprintf('Same sequence as the static ideal plant (algos.py): %d of %d runs.\n', sum(T.same_as_ideal), height(T));
fprintf('Largest duty difference from the static RL plant: %.2e (Idea B refined: its corner duties follow the measured V and I)\n', ...
        max(T.max_abs_dD_RL));
fprintf('Largest error of a measured probe power against the static RL point: %.3f %%\n', ...
        max(T.max_abs_probe_dP_pct));
writetable(T, fullfile(resDir, 'gmppt_controller_check.csv'));
save(fullfile(resDir, 'gmppt_controller_check.mat'), 'T', 'cfg');

%% Local functions
function [ok, j] = sameSeq(a, b)
% True if the two duty sequences are the same. j: first probe that
% differs (0 if none).
n = min(numel(a), numel(b));
j = find(abs(a(1:n) - b(1:n)) > 1e-9, 1);
if isempty(j)
    j = 0;
    if numel(a) ~= numel(b), j = n + 1; end
end
ok = (j == 0);
end

function s = seqText(ok, j)
if ok, s = 'same'; else, s = sprintf('probe %d', j); end
end
