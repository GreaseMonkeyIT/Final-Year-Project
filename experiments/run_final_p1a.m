%RUN_FINAL_P1A Phase 1a of the final tests: the mid-review tests on the new bench.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 4, block
%   1a). P&O and INC from start-up (p.alg = 1, 2) on the cases of
%   run_po_demo.m (set A: the nine patterns, set B: P1 and P3 from another
%   start duty, set C: R1, P1, P0 in turn), on MPPT_4x4.slx with the
%   sensors and the ADC on (sens_draw.m, one seed for each run), 25 degC.
%   The reference is the run without noise (results/mppt_results.mat).
%
%   Outputs in the folder "results": final_p1a.mat, final_p1a.csv
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
O   = load(fullfile(resIn, 'mppt_results.mat'));
if quick, O.R = O.R(1:2); end
kR = 1:numel(O.R);                         % Index of each run in the first run (seed of sens_draw)
if incOnly, kR = find([O.R.alg] == 2); O.R = O.R(kR); end
S   = load(fullfile(resIn, 'pv4x4_sweeps.mat')); sw = S.res; ids = {sw.id};
runs = struct('mppt', {}, 'Gsched', {}, 'Tstop', {}, 'T', {}, 'sens', {});
for k = 1:numel(O.R)
    r = O.R(k);
    c = O.cases(find(strcmp({O.cases.id}, r.id) & [O.cases.set] == r.set, 1));
    m = cfg.mppt; m.alg = r.alg; m.Dstart = c.Dstart; m.T_rescan = 0;
    runs(end+1) = struct('mppt', m, 'Gsched', c.Gsched, 'Tstop', c.Tstop, 'T', 25, ...
                         'sens', sens_draw(cfg.sens, 500 + kR(k))); %#ok<SAGROW>
end
[out, info] = bench_sim('MPPT_4x4', runs, projectDir);

fid = fopen(fullfile(resDir, ['final_p1a' sfx '.csv']), 'w');
fprintf(fid, 'alg,set,pattern,Dstart,pct_noise_off,pct_noise_on,V_swing_on_V\n');
fprintf('\n%-4s %-3s %-9s %7s %10s %10s %8s\n', 'Alg', 'Set', 'Pattern', 'Dstart', 'Off %', 'On %', 'Swing V');
R = struct([]);
for k = 1:numel(O.R)
    r = O.R(k); o = out(k);
    c = O.cases(find(strcmp({O.cases.id}, r.id) & [O.cases.set] == r.set, 1));
    if ~isempty(o.ErrorMessage), fprintf('Run %d: %s\n', k, o.ErrorMessage); continue, end
    t = o.Ppv.Time; P = o.Ppv.Data; V = o.Vpv.Data; last = t > c.Tstop - 0.3;
    endId = r.id; if r.set == 'C', endId = 'P0'; end
    g = sw(strcmp(ids, endId)).gmpp(2);
    pOff = 100 * r.Pend / g; pOn = 100 * mean(P(last)) / g; swing = max(V(last)) - min(V(last));
    fprintf('%-4s %-3s %-9s %7.2f %10.3f %10.3f %8.2f\n', r.algName, r.set, r.id, c.Dstart, pOff, pOn, swing);
    fprintf(fid, '%s,%s,%s,%.2f,%.3f,%.3f,%.3f\n', r.algName, r.set, r.id, c.Dstart, pOff, pOn, swing);
    e = struct('alg', r.alg, 'set', r.set, 'id', r.id, 'pOff', pOff, 'pOn', pOn, 'swing', swing, 't', t, 'P', P);
    if isempty(R), R = e; else, R(end+1) = e; end %#ok<AGROW>
end
fclose(fid);
save(fullfile(resDir, ['final_p1a' sfx '.mat']), 'R', 'info');
