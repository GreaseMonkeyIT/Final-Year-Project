%CHECK_REGRESSION Pass gate 0.6 of the test bench: the new bench gives the old results.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 3, step
%   0.6). With the sensors off (sens.on = 0) and 25 degC, MPPT_4x4.slx
%   must give the results of the runs made before the bench changes:
%     1. P&O and INC from start-up (p.alg = 1, 2), the cases of
%        run_po_demo.m, against results/mppt_results.mat.
%     2. DIRECT, Idea B and Idea C with the parabolic stage on the nine
%        patterns, 4 s, against results/gmppt_local3.mat (part 1).
%   Pass: the final power differs by less than 0.01 % of the GMPP.
%   Smoke runs (no pass value, they must run without an error):
%     3. Each search with each local stage (1 to 4) on R1.
%     4. DIRECT on P0 at 55 degC, and DIRECT on R1 with the sensors on.
%   Last, coder.screener on the controller files and on sensor_adc.m.
%
%   Output: results/check_regression.txt. 4 workers (sim_pool.m).

clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
logf = fopen(fullfile(resDir, 'check_regression.txt'), 'w');
say(logf, 'check_regression.m, %s\n', char(datetime('now')));
cfg = pv4x4_config();
mdl = 'MPPT_4x4';
load_system(fullfile(projectDir, 'models', [mdl '.slx']));
O  = load(fullfile(resDir, 'mppt_results.mat'));
L3 = load(fullfile(resDir, 'gmppt_local3.mat'));
S  = load(fullfile(resDir, 'pv4x4_sweeps.mat')); sw = S.res; ids = {sw.id};
gm = @(id) sw(strcmp(ids, id));
mk = @(m, Gs, Tstop) Simulink.SimulationInput(mdl).setVariable('mppt', m, 'Workspace', mdl) ...
     .setVariable('Gsched', Gs, 'Workspace', mdl).setVariable('Tstop', Tstop, 'Workspace', mdl);

in = Simulink.SimulationInput.empty; tag = {};
% 1. P&O and INC.
for k = 1:numel(O.R)
    r = O.R(k);
    c = O.cases(find(strcmp({O.cases.id}, r.id) & [O.cases.set] == r.set, 1));
    m = cfg.mppt; m.alg = r.alg; m.Dstart = c.Dstart; m.T_rescan = 0;
    in(end+1) = mk(m, c.Gsched, c.Tstop); tag{end+1} = {1, k, c.Tstop}; %#ok<SAGROW>
end
% 2. Parabolic stage after DIRECT, Idea B and Idea C.
R3 = L3.R([L3.R.part] == 1 & [L3.R.var] == 3);
for k = 1:numel(R3)
    m = cfg.mppt; m.alg = R3(k).alg; m.local = 3; m.T_rescan = 0;
    in(end+1) = mk(m, [0 gm(R3(k).pats{1}).G(:)'], 4); tag{end+1} = {2, k, 4}; %#ok<SAGROW>
end
% 3. Each search with each local stage on R1.
for a = 3:7
    for lc = 1:4
        m = cfg.mppt; m.alg = a; m.local = lc; m.T_rescan = 0;
        in(end+1) = mk(m, [0 gm('R1').G(:)'], 4); tag{end+1} = {3, [a lc], 4}; %#ok<SAGROW>
    end
end
% 4. Temperature and sensors.
m = cfg.mppt; m.alg = 3; m.T_rescan = 0;
in(end+1) = mk(m, [0 gm('P0').G(:)'], 4).setVariable('pv_T', 55, 'Workspace', mdl); tag{end+1} = {4, 1, 4};
sn = cfg.sens; sn.on = 1;
in(end+1) = mk(m, [0 gm('R1').G(:)'], 4).setVariable('sens', sn, 'Workspace', mdl); tag{end+1} = {4, 2, 4};

sim_pool(4);
t0 = tic;
out = parsim(in, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
             'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
say(logf, '%d runs in %.0f s on 4 workers\n', numel(in), toc(t0));

d1 = []; d2 = []; nErr = 0;
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
for k = 1:numel(in)
    o = out(k); g = tag{k};
    if ~isempty(o.ErrorMessage)
        nErr = nErr + 1; say(logf, 'Run %d (block %d): %s\n', k, g{1}, o.ErrorMessage); continue
    end
    t = o.Ppv.Time; P = o.Ppv.Data; Pe = mean(P(t > g{3} - 0.3));
    switch g{1}
        case 1
            r = O.R(g{2});
            eid = r.id; if r.set == 'C', eid = 'P0'; end
            gmp = gm(eid).gmpp(2);
            d1(end+1) = 100 * abs(Pe - r.Pend) / gmp; %#ok<SAGROW>
        case 2
            r = R3(g{2});
            d2(end+1) = abs(100 * Pe / r.Pgmpp - r.pct); %#ok<SAGROW>
        case 3
            say(logf, '  R1, %-6s local %d: end %.3f %% of the GMPP\n', algName{g{2}(1)}, g{2}(2), ...
                100 * Pe / gm('R1').gmpp(2));
        case 4
            if g{2} == 1
                c = pv_array_curve(gm('P0').G, 55, cfg);
                say(logf, '  P0 at 55 degC: end %.1f W, static GMPP %.1f W (%.3f %%)\n', Pe, c.gmpp(2), 100 * Pe / c.gmpp(2));
            else
                say(logf, '  R1 with the sensors on: end %.3f %% of the GMPP\n', 100 * Pe / gm('R1').gmpp(2));
            end
    end
end
say(logf, '1. P&O and INC: %d runs, largest difference of the final power %.6f %% of the GMPP\n', numel(d1), max(d1));
say(logf, '2. Parabolic stage: %d runs, largest difference %.6f points\n', numel(d2), max(d2));
pass = nErr == 0 && max(d1) < 0.01 && max(d2) < 0.01 && numel(d1) == numel(O.R) && numel(d2) == numel(R3);
for f = {'src/controller/mppt_controller.m', 'src/controller/gmppt_search.m', 'src/controller/gmppt_pso.m', ...
         'src/controller/gmppt_gwo.m', 'src/plant/sensor_adc.m'}
    sc = coder.screener(fullfile(projectDir, f{1}));
    say(logf, 'screener %s: %d messages, %d unsupported calls\n', f{1}, numel(sc.Messages), numel(sc.UnsupportedCalls));
end
if pass, say(logf, 'Gate 0.6 PASS\n'); else, say(logf, 'Gate 0.6 FAIL\n'); end
fclose(logf);

function say(fid, varargin)
fprintf(varargin{:});
fprintf(fid, varargin{:});
end
