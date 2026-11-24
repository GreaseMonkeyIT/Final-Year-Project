%RUN_FINAL_P1B Phase 1b of the final tests: static shading on the static test bench.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 4, block
%   1b). The plant is the static array model (src/plant/static_run.m, MEX
%   file). Each run lasts 4 s from start-up. All five searches hand over
%   to the parabolic stage (p.local = 3).
%     Patterns  the nine patterns of shading_patterns.m, the three of
%               shading_patterns_grp.m and the 900 of random_patterns.m
%               (300 panel, 300 edge, 300 group)
%     Cell temperature  25 degC and 55 degC
%     Noise off  exact measurement. DIRECT, Idea B and Idea C: one run.
%               PSO and GWO: 30 seeds of their random generator.
%     Noise on  sensors and ADC (sensor_adc.m) with random static errors
%               (sens_draw.m). DIRECT, Idea B and Idea C: 5 seeds. PSO and
%               GWO: 30 seeds (generator and sensors).
%   Values of each run (bench_metrics.m, t0 = end of the start-up wait):
%   final power (mean of the last 0.3 s, % of the GMPP), efficiency over
%   the run, length of the first search, hand-over time, end on a wrong
%   peak.
%
%   Outputs in the folder "results": final_p1b.mat, final_p1b.csv
%   (summary), final_p1b.txt. Run build/build_static_mex.m first.
%   FINAL_QUICK set in the environment: a smoke test with a few cases,
%   outputs in results/quick.


clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
quick = ~isempty(getenv('FINAL_QUICK'));   % Smoke test: few cases, outputs in results/quick
if quick, resDir = fullfile(resDir, 'quick'); if ~isfolder(resDir), mkdir(resDir); end, end
cfg  = pv4x4_config();
logf = fopen(fullfile(resDir, 'final_p1b.txt'), 'w');
say(logf, 'run_final_p1b.m, %s\n', char(datetime('now')));

%% Patterns and curves
P9 = shading_patterns(); P3 = shading_patterns_grp(); PR = random_patterns(300 - 298 * quick, 1);
pat = struct('id', {}, 'kind', {}, 'G', {});
for k = 1:numel(P9), pat(end+1) = struct('id', P9(k).id, 'kind', 'nine', 'G', P9(k).G); end %#ok<SAGROW>
for k = 1:numel(P3), pat(end+1) = struct('id', P3(k).id, 'kind', 'grp', 'G', P3(k).G); end %#ok<SAGROW>
for k = 1:numel(PR), pat(end+1) = struct('id', sprintf('%s%03d', PR(k).kind(1), PR(k).k), 'kind', PR(k).kind, ...
                                        'G', PR(k).G); end %#ok<SAGROW>
Ts = [25 55];
nP = numel(pat); nT = numel(Ts);
sim_pool(4);
t0 = tic;
B = cell(nP, nT);
parfor q = 1:nP * nT
    [ip, it] = ind2sub([nP nT], q);
    B{q} = bench_curve(pat(ip).G, Ts(it), cfg); %#ok<PFBNS>
end
say(logf, '%d curves in %.0f s\n', nP * nT, toc(t0));

%% Runs
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
nSeedRand = 30 - 28 * quick; nSeedDet = 5 - 3 * quick;
% One block of runs for each curve: [alg, noise, seed].
blk = zeros(0, 3);
for a = 3:7
    for nz = 0:1
        if a >= 6, nsd = nSeedRand; elseif nz, nsd = nSeedDet; else, nsd = 1; end
        blk = [blk; repmat([a nz], nsd, 1) (1:nsd)']; %#ok<AGROW>
    end
end
nb  = size(blk, 1);
q   = repelem((1:nP * nT)', nb, 1);
[~, itq] = ind2sub([nP nT], q);
job = [q repmat(blk(:, 1:2), nP * nT, 1) repmat(blk(:, 3), nP * nT, 1) itq];   % [curve, alg, noise, seed, T index]
say(logf, '%d runs\n', size(job, 1));
rinA = [cfg.conv.Rload cfg.conv.RL];
p0 = cfg.mppt; p0.local = 3 * ones(size(p0.local)); p0.T_rescan = 0;
s0 = cfg.sens;
tw = p0.Nwait * p0.Tmppt;                  % End of the start-up wait [s]
res = zeros(size(job, 1), 7);              % [pctEnd, eta, tSrch, tHand, wrongEnd, pctHand, Lwrong]
t0 = tic;
parfor r = 1:size(job, 1)
    jb = job(r, :); b = B{jb(1)}; %#ok<PFBNS>
    p = final_variant(p0, struct('alg', jb(2), 'loc', 3 + 2 * (jb(2) == 3)));   % DIRECT as in its paper (2026-11-23)
    p.rng_seed = 1000 + jb(4);
    s = s0;
    if jb(3) == 1, s = sens_draw(s0, 100 * jb(1) + jb(4)); end
    [Pl, Vl, ~, phl] = static_run_mex(b.Vg, b.I, b.gmpp(2), 0, 0, 0, 1e-6, 4, 40, rinA, p, s);
    t = (1:numel(Pl))' * 2e-3;
    ref = struct('ic', ones(size(t)), 'curves', struct('gmpp', b.gmpp, 'peaks', b.peaks), 't0', tw);
    m = bench_metrics(t, Vl, Pl, phl, ref);
    kh = find(phl == 2, 1);
    tHand = NaN; pHand = NaN;
    if ~isempty(kh)
        tHand = t(kh);
        pHand = 100 * mean(Pl(kh:min(kh + 9, numel(Pl)))) / b.gmpp(2);
    end
    tS = NaN; if ~isempty(m.tSrch), tS = m.tSrch(1); end
    res(r, :) = [100 * mean(Pl(t > 3.7)) / b.gmpp(2), m.eta, tS, tHand, m.wrongEnd, pHand, m.Lwrong];
end
tRun = toc(t0);
say(logf, 'Runs done in %.0f s on 4 workers\n', tRun);

%% Summary
kindOf = {pat.kind};
[ipAll, ~] = ind2sub([nP nT], job(:, 1));
kinds = {'nine', 'grp', 'panel', 'edge', 'group', 'all'};
fid = fopen(fullfile(resDir, 'final_p1b.csv'), 'w');
fprintf(fid, 'set,T_degC,noise,search,runs,pct_end_mean,pct_end_min,pct_end_below99_pct,wrong_end_pct,eta_mean,eta_min,t_search_mean_s,t_search_max_s,t_hand_max_s\n');
say(logf, '\n%-6s %3s %5s %-7s %6s %15s %8s %8s %15s %13s\n', 'Set', 'T', 'Noise', 'Search', 'Runs', ...
    'End % mean/min', '<99 %', 'Wrong %', 'Eta % mean/min', 't srch mn/max');
for kk = 1:numel(kinds)
    if strcmp(kinds{kk}, 'all'), inK = true(size(ipAll)); else, inK = strcmp(kindOf(ipAll), kinds{kk})'; end
    for it = 1:nT
        for nz = 0:1
            for a = 3:7
                sel = inK & job(:, 5) == it & job(:, 3) == nz & job(:, 2) == a;
                X = res(sel, :);
                v = [nnz(sel), mean(X(:, 1)), min(X(:, 1)), 100 * mean(X(:, 1) < 99), 100 * mean(X(:, 5)), ...
                     mean(X(:, 2)), min(X(:, 2)), mean(X(:, 3), 'omitnan'), max(X(:, 3)), max(X(:, 4))];
                fprintf(fid, '%s,%d,%d,%s,%d,%.3f,%.3f,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f\n', kinds{kk}, Ts(it), nz, ...
                        algName{a}, v);
                say(logf, '%-6s %3d %5d %-7s %6d %7.3f/%7.3f %8.2f %8.2f %7.3f/%7.3f %6.2f/%6.2f\n', kinds{kk}, Ts(it), ...
                    nz, algName{a}, v(1:7), v(8:9));
            end
        end
    end
end
fclose(fid);
% Worst cases of each search (all sets, both temperatures, both noise settings).
say(logf, '\nWorst final power of each search:\n');
for a = 3:7
    sel = find(job(:, 2) == a);
    [~, w] = min(res(sel, 1)); r = sel(w); [ip, it] = ind2sub([nP nT], job(r, 1));
    say(logf, '  %-7s %.3f %% on %s (%s), %d degC, noise %d, seed %d, wrong end %d\n', algName{a}, res(r, 1), ...
        pat(ip).id, pat(ip).kind, Ts(it), job(r, 3), job(r, 4), res(r, 5));
end
save(fullfile(resDir, 'final_p1b.mat'), 'job', 'res', 'pat', 'Ts', 'cfg', 'tRun', 'nSeedRand', 'nSeedDet');
fclose(logf);

function say(fid, varargin)
fprintf(varargin{:});
fprintf(fid, varargin{:});
end
