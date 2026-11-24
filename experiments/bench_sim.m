function [out, info] = bench_sim(mdl, runs, projectDir)
%BENCH_SIM Run a list of cases on MPPT_4x4.slx or MPPT_4x4_grp.slx with parsim.
%
%   [out, info] = bench_sim(mdl, runs, projectDir) runs each entry of the
%   struct array runs on the model mdl with 4 workers (sim_pool.m). Fields
%   of each entry:
%     mppt    controller values (cfg.mppt with the changes of the case)
%     Gsched  irradiance schedule, rows [t, G(:)']
%     Tstop   stop time [s]
%     T       cell temperature [degC]
%     sens    sensor values (cfg.sens, or sens_draw.m for noise on)
%   info has the wall time [s] and the largest RAM use of the MATLAB
%   processes that the function saw [GiB] (sampled before and after).
%   A run that stops because the Simscape solver does not converge runs
%   once more with the solver daessc. info.retried lists these runs.
%   Made on 2026-11-21 for the final tests (docs/notes/final_test_plan.md).

load_system(fullfile(projectDir, 'models', [mdl '.slx']));
in = Simulink.SimulationInput.empty;
for k = 1:numel(runs)
    r = runs(k);
    s = Simulink.SimulationInput(mdl);
    s = s.setVariable('mppt',   r.mppt,   'Workspace', mdl);
    s = s.setVariable('Gsched', r.Gsched, 'Workspace', mdl);
    s = s.setVariable('Tstop',  r.Tstop,  'Workspace', mdl);
    s = s.setVariable('pv_T',   r.T,      'Workspace', mdl);
    s = s.setVariable('sens',   r.sens,   'Workspace', mdl);
    in(end+1) = s; %#ok<AGROW>
end
nW = str2double(getenv('FINAL_WORKERS'));     % Workers: 4, or FINAL_WORKERS from the environment
if isnan(nW), nW = 4; end
% A number in results/WORKERS overrides both. A running chain of
% run_final_all.sh reads it at the start of each phase.
wf = fullfile(projectDir, 'results', 'WORKERS');
if isfile(wf)
    w = str2double(strtrim(fileread(wf)));
    if ~isnan(w) && w >= 1, nW = w; end
end
sim_pool(nW);
t0 = tic;
out = parsim(in, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
             'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
% A run can stop with "Transient initialization ... failed to converge" of
% the Simscape solver after a large duty jump (GWO + parabolic stage, phase 3
% of the second run, 2026-11-23). Such a run runs once more with the solver
% daessc (added on 2026-11-24). On runs that do not fail, daessc and ode23t
% gave the same efficiency within 0.002 points on 4 of 5 checked runs, and
% within 0.22 points on the fifth (scratch check of 2026-11-24).
info.retried = [];
bad = find(arrayfun(@(o) ~isempty(o.ErrorMessage) && contains(o.ErrorMessage, 'failed to converge'), out));
if ~isempty(bad)
    in2 = in(bad);
    for j = 1:numel(in2)
        in2(j) = in2(j).setModelParameter('Solver', 'daessc');
    end
    out2 = parsim(in2, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
                  'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
    for j = 1:numel(bad)
        out(bad(j)) = out2(j);
        if isempty(out2(j).ErrorMessage), res = 'ok'; else, res = 'failed again'; end
        fprintf('Run %d: the solver did not converge, run again with daessc: %s\n', bad(j), res);
    end
    info.retried = bad(:)';
end
info.wall = toc(t0);
info.ramGiB = matlabRam();
info.simSeconds = sum([runs.Tstop]);
info.workers = nW;
fprintf('%s: %d runs, %.0f s simulated, %.0f s wall (%.2f s per simulated s on %d workers), MATLAB RAM %.1f GiB\n', ...
        mdl, numel(runs), info.simSeconds, info.wall, nW * info.wall / info.simSeconds, nW, info.ramGiB);
end

function g = matlabRam()
% Sum of the working sets of the MATLAB processes [GiB] (Windows only).
g = NaN;
if ispc
    [st, txt] = system(['powershell -NoProfile -Command "(Get-Process | Where-Object { $_.ProcessName ' ...
                        '-match ''MATLAB'' } | Measure-Object WorkingSet64 -Sum).Sum"']);
    if st == 0, g = str2double(strtrim(txt)) / 2^30; end
end
end
