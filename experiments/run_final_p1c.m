%RUN_FINAL_P1C Phase 1c of the final tests: global searches in Simulink on a subset.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 4, block
%   1c). The subset has 99 patterns of phase 1b:
%     - the nine patterns of shading_patterns.m and the three of
%       shading_patterns_grp.m,
%     - for each random kind (panel, edge, group): the 10 patterns with
%       the lowest final power of any search in phase 1b (25 degC, noise
%       on), and 19 other patterns drawn at random (seed 7).
%   Each pattern runs on MPPT_4x4_grp.slx for 4 s from start-up with the
%   five searches and the parabolic stage, the sensors on (sens_draw.m)
%   and 25 degC. PSO and GWO use seed 1. The static result of the same
%   case (phase 1b, seed 1) is next to each Simulink result.
%
%   Since 2026-11-23 DIRECT runs as in its paper (its own P&O ending,
%   final_variant.m), the other searches with the parabolic stage.
%   FINAL_P1C_PRIOR set in the environment to the path of an earlier
%   final_p1c.mat: the run keeps the 99 patterns and the rows of Idea B,
%   Idea C, PSO and GWO of that file, and runs only DIRECT. The start-up
%   runs of these four searches do not depend on the restart rule.
%
%   Outputs in the folder "results": final_p1c.mat, final_p1c.csv
%   Run run_final_p1b.m first.
%   FINAL_QUICK set in the environment: a smoke test with a few cases,
%   outputs in results/quick.


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
cfg = pv4x4_config();
B1  = load(fullfile(resDir, 'final_p1b.mat'));   % results/quick in a smoke test
nP  = numel(B1.pat); nT = numel(B1.Ts);
[ipJ, itJ] = ind2sub([nP nT], B1.job(:, 1));
kindOf = {B1.pat.kind};

% Selection.
sel = find(ismember(kindOf, {'nine', 'grp'}));
rs  = RandStream('mt19937ar', 'Seed', 7);
for kd = {'panel', 'edge', 'group'}
    cand = find(strcmp(kindOf, kd{1}));
    worst = zeros(size(cand));
    for j = 1:numel(cand)
        m = ipJ == cand(j) & itJ == 1 & B1.job(:, 3) == 1;
        worst(j) = min(B1.res(m, 1));
    end
    [~, o] = sort(worst);
    nh = min(10, numel(cand) - 1); nr = min(19, numel(cand) - nh);
    hard = cand(o(1:nh));
    rest = setdiff(cand, hard);
    sel = [sel, hard, rest(randperm(rs, numel(rest), nr))]; %#ok<AGROW>
end
say = @(varargin) fprintf(varargin{:});
prior = []; algRun = 3:7;
if ~isempty(getenv('FINAL_P1C_PRIOR'))
    prior = load(getenv('FINAL_P1C_PRIOR'), 'R', 'sel');
    sel = prior.sel; algRun = 3;
    say('Patterns and rows of Idea B, Idea C, PSO, GWO from %s\n', getenv('FINAL_P1C_PRIOR'));
end
if quick, sel = sel(sel <= nP); sel = sel([1 end]); end   % The quick p1b has fewer patterns
say('%d patterns in the subset\n', numel(sel));

runs = struct('mppt', {}, 'Gsched', {}, 'Tstop', {}, 'T', {}, 'sens', {});
key  = zeros(0, 2);
for ip = sel
    G = B1.pat(ip).G;
    if size(G, 1) == 4, G = kron(G, ones(3, 1)); end
    for a = algRun
        m = final_variant(cfg.mppt, struct('alg', a, 'loc', 3 + 2 * (a == 3))); m.T_rescan = 0; m.rng_seed = 1001;
        runs(end+1) = struct('mppt', m, 'Gsched', [0 G(:)'], 'Tstop', 4, 'T', 25, ...
                             'sens', sens_draw(cfg.sens, 100 * ip + 1)); %#ok<SAGROW>
        key(end+1, :) = [ip a]; %#ok<SAGROW>
    end
end
[out, info] = bench_sim('MPPT_4x4_grp', runs, projectDir);

algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
R = zeros(numel(runs), 8);                 % [pattern, alg, pctSim, pctStatic, tHandSim, tHandStatic, wrongSim, wrongStatic]
for k = 1:numel(runs)
    ip = key(k, 1); a = key(k, 2); o = out(k);
    js = find(ipJ == ip & itJ == 1 & B1.job(:, 2) == a & B1.job(:, 3) == 1 & B1.job(:, 4) == 1, 1);
    b = bench_curve(B1.pat(ip).G, 25, cfg);
    if ~isempty(o.ErrorMessage), say('Run %d: %s\n', k, o.ErrorMessage); R(k, :) = NaN; continue, end
    t = o.Ppv.Time; P = o.Ppv.Data; V = o.Vpv.Data;
    tp = o.ph.Time; ph = squeeze(o.ph.Data);
    phI = interp1(tp, ph, t, 'previous', 'extrap');
    ref = struct('ic', ones(size(t)), 'curves', struct('gmpp', b.gmpp, 'peaks', b.peaks), 't0', 0.06);
    m = bench_metrics(t, V, P, phI, ref);
    kh = find(ph == 2, 1); tH = NaN; if ~isempty(kh), tH = tp(kh); end
    R(k, :) = [ip a 100 * mean(P(t > 3.7)) / b.gmpp(2) B1.res(js, 1) tH B1.res(js, 4) m.wrongEnd B1.res(js, 5)];
end

if ~isempty(prior)
    R = [R; prior.R(prior.R(:, 2) ~= 3 & ismember(prior.R(:, 1), sel), :)];
    R = sortrows(R, [1 2]);
end
fid = fopen(fullfile(resDir, 'final_p1c.csv'), 'w');
fprintf(fid, 'pattern,kind,search,pct_end_simulink,pct_end_static,t_hand_simulink_s,t_hand_static_s,wrong_simulink,wrong_static\n');
for k = 1:size(R, 1)
    if isnan(R(k, 1)), continue, end
    fprintf(fid, '%s,%s,%s,%.3f,%.3f,%.3f,%.3f,%d,%d\n', B1.pat(R(k, 1)).id, B1.pat(R(k, 1)).kind, algName{R(k, 2)}, R(k, 3:end));
end
fclose(fid);
say('\n%-7s %15s %8s %10s %12s\n', 'Search', 'Sim end mn/min', 'Wrong', 'Static', '|dEnd| max');
for a = 3:7
    X = R(R(:, 2) == a & ~isnan(R(:, 3)), :);
    say('%-7s %7.3f/%7.3f %8d %10.3f %12.3f\n', algName{a}, mean(X(:, 3)), min(X(:, 3)), sum(X(:, 7)), ...
        mean(X(:, 4)), max(abs(X(:, 3) - X(:, 4))));
end
save(fullfile(resDir, 'final_p1c.mat'), 'R', 'sel', 'info');
