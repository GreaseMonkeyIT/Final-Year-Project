%RUN_FINAL_P1D Phase 1d of the final tests: the local stages against one another.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 4, block
%   1d). Each of the five searches (p.alg = 3 to 7: DIRECT, Idea B, Idea
%   C, PSO, GWO) hands over to each of the four local stages: 1 P&O, 2
%   variable-step INC of Liu et al. (2008), 3 parabolic stage, 4 INC of the
%   mid-review. With the same search and the same sensor errors, the four
%   stages start from the same hand-over.
%   Patterns: the nine patterns of shading_patterns.m and the first 20
%   random patterns of the phase 1c subset. MPPT_4x4_grp.slx, 4 s from
%   start-up, 25 degC, sensors on (sens_draw.m), PSO and GWO with seed
%   1001. Changed on 2026-11-22 with the approval of the user: all five
%   searches (before: DIRECT only), and only sensors on (before: off and
%   on; the run of 2026-11-22 gave the same values within 0.03 points).
%   Values: final power, efficiency from the hand-over to the end, voltage
%   swing in the last 0.3 s, duty moves of at least 0.0005 in the last 2 s
%   (the small corrections of the voltage hold do not count), end on a
%   wrong peak.
%
%   Outputs in the folder "results": final_p1d.mat, final_p1d.csv
%   Run run_final_p1c.m first.
%   FINAL_QUICK set in the environment: a smoke test with a few cases,
%   outputs in results/quick.
%   FINAL_INC set in the environment: only the variants with an INC
%   (local stages 2 and 4), outputs final_p1d_inc.*. Added on 2026-11-22
%   for the rerun after the fix of the INC hold.


clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
if isfile(fullfile(projectDir, 'results', 'STOP'))      % Pause of the final tests: skip this phase
    fprintf('results/STOP exists: phase skipped\n'); return
end
resDir = fullfile(projectDir, 'results');
quick = ~isempty(getenv('FINAL_QUICK'));   % Smoke test: few cases, outputs in results/quick
if quick, resDir = fullfile(resDir, 'quick'); if ~isfolder(resDir), mkdir(resDir); end, end
incOnly = ~isempty(getenv('FINAL_INC'));   % Rerun of the INC variants only (fix of 2026-11-22),
sfx = ''; if incOnly, sfx = '_inc'; end    % outputs final_<phase>_inc.*
cfg = pv4x4_config();
B1  = load(fullfile(resDir, 'final_p1b.mat'));
C1  = load(fullfile(resDir, 'final_p1c.mat'));
kindOf = {B1.pat.kind};
selR = C1.sel(~ismember(kindOf(C1.sel), {'nine', 'grp'}));
sel  = [find(strcmp(kindOf, 'nine')), selR(1:min(20, numel(selR)))];
if quick, sel = sel([1 end]); end
locName = {'P&O', 'VS-INC', 'Parabolic', 'INC'};
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
lcs  = 1:4; if incOnly, lcs = [2 4]; end
algs = 3:7; if quick, algs = [3 4]; end

runs = struct('mppt', {}, 'Gsched', {}, 'Tstop', {}, 'T', {}, 'sens', {});
key  = zeros(0, 3);                        % [pattern, alg, local]
for ip = sel
    G = B1.pat(ip).G;
    if size(G, 1) == 4, G = kron(G, ones(3, 1)); end
    for a = algs
        for lc = lcs
            m = cfg.mppt; m.alg = a; m.local = lc * ones(size(m.local)); m.T_rescan = 0; m.rng_seed = 1001;
            s = sens_draw(cfg.sens, 100 * ip + 3);
            runs(end+1) = struct('mppt', m, 'Gsched', [0 G(:)'], 'Tstop', 4, 'T', 25, 'sens', s); %#ok<SAGROW>
            key(end+1, :) = [ip a lc]; %#ok<SAGROW>
        end
    end
end
[out, info] = bench_sim('MPPT_4x4_grp', runs, projectDir);

R = nan(numel(runs), 8);                   % [pattern, alg, local, pctEnd, etaLocal, Vswing, nMoves, wrongEnd]
for k = 1:numel(runs)
    o = out(k); ip = key(k, 1);
    R(k, 1:3) = key(k, :);
    if ~isempty(o.ErrorMessage), fprintf('Run %d: %s\n', k, o.ErrorMessage); continue, end
    b = bench_curve(B1.pat(ip).G, 25, cfg);
    t = o.Ppv.Time; P = o.Ppv.Data; V = o.Vpv.Data;
    tp = o.ph.Time; ph = squeeze(o.ph.Data); kh = find(ph == 2, 1);
    tD = o.D.Time; D = squeeze(o.D.Data);
    last = t > 3.7; loc = t >= tp(kh);
    [~, ig] = max(b.peaks(:, 2)); [~, in] = min(abs(mean(V(last)) - b.peaks(:, 1)));
    R(k, 4:8) = [100 * mean(P(last)) / b.gmpp(2), 100 * mean(P(loc)) / b.gmpp(2), max(V(last)) - min(V(last)), ...
                 sum(abs(diff(D(tD > 2))) >= 5e-4), double(in ~= ig)];
end
fid = fopen(fullfile(resDir, ['final_p1d' sfx '.csv']), 'w');
fprintf(fid, 'pattern,search,local_stage,pct_end,pct_local_stage,V_swing_V,duty_moves_last_2s,wrong_end\n');
for k = 1:size(R, 1)
    fprintf(fid, '%s,%s,%s,%.3f,%.3f,%.3f,%d,%d\n', B1.pat(R(k, 1)).id, algName{R(k, 2)}, locName{R(k, 3)}, R(k, 4:end));
end
fclose(fid);
fprintf('\n%-7s %-10s %15s %15s %8s %7s %6s\n', 'Search', 'Local', 'End % mn/min', 'Local % mn/min', 'Swing', 'Moves', 'Wrong');
for a = algs
    for lc = lcs
        X = R(R(:, 2) == a & R(:, 3) == lc & ~isnan(R(:, 4)), :);
        fprintf('%-7s %-10s %7.3f/%7.3f %7.3f/%7.3f %8.2f %7.1f %6d\n', algName{a}, locName{lc}, mean(X(:, 4)), ...
                min(X(:, 4)), mean(X(:, 5)), min(X(:, 5)), mean(X(:, 6)), mean(X(:, 7)), sum(X(:, 8)));
    end
end
save(fullfile(resDir, ['final_p1d' sfx '.mat']), 'R', 'sel', 'info', 'locName', 'algName');
