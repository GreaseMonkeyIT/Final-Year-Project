%RUN_FINAL_P3N Restart rule under sensor noise: changes that need a search.
%
%   Made on 2026-11-22 at the request of the user (docs/notes/
%   final_test_plan.md, section 14). Phase 5 showed that heavy sensor noise
%   (10 and 30 times the values of pv4x4_config.m) breaks the steady
%   condition of the restart rule, so no search starts. On uniform ramps
%   this looks like a gain. This phase measures the cost: changes where the
%   global peak moves and a search is necessary. Static bench only
%   (static_run.m, MEX file), 25 degC.
%     Set A  the 40 cloud events of phase 3 (cloud_events.m, seed 11).
%     Set B  100 steps from one pattern to another at t = 4 s, 10 s in all.
%            The pairs come from the 900 random patterns of phase 1b
%            (random_patterns.m), drawn with seed 5, kept only if the GMPP
%            voltage moves by more than 10 % and the old operating peak
%            gives less than 98 % of the new GMPP.
%   Noise: the noise values nV, nI and adc_n of sens_draw.m times 1, 3, 10
%   and 30 (as phase 5). Static errors of sens_draw.m (one draw per case).
%   Variants: the five searches with the parabolic stage, and DIRECT with
%   the local stages 1, 2 and 4 (as phase 3). T_rescan = 0, so only the
%   level test can start a search.
%   Values of each run, from the change (set A: from t = 3 s):
%     eta     energy over the energy of the GMPP [%]
%     nSrch   searches after the change
%     wrong   the run ends on a wrong peak
%     tRec    recovery time [s] from the end of the change to the first
%             time after which the power stays at 99 % of the GMPP or more.
%             NaN: no recovery before the end.
%
%   Outputs in the folder "results": final_p3n.mat, final_p3n.csv,
%   final_p3n.txt. Run experiments/oahu_fit.m and build/build_static_mex.m first.
%   FINAL_QUICK set in the environment: a smoke test with a few cases,
%   outputs in results/quick.


clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
resIn = resDir;
quick = ~isempty(getenv('FINAL_QUICK'));   % Smoke test: few cases, outputs in results/quick
if quick, resDir = fullfile(resDir, 'quick'); if ~isfolder(resDir), mkdir(resDir); end, end
cfg = pv4x4_config();
logf = fopen(fullfile(resDir, 'final_p3n.txt'), 'w');
say(logf, 'run_final_p3n.m, %s\n', char(datetime('now')));
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
locName = {'P&O', 'VS-INC', 'Parabolic', 'INC'};
var = final_variants();                    % Final comparison (2026-11-23), final_variant.m
if quick, var = var([1 3]); end
vname = @final_vname;
nsc = [1 3 10 30];
if quick, nsc = [1 30]; end
rinA = [cfg.conv.Rload cfg.conv.RL];
Vg = linspace(0, 200, 4000)';
sim_pool(6);

%% Set A: cloud events (curves every 0.05 s, as phase 3)
F  = load(fullfile(resIn, 'oahu_fit.mat'));
ev = cloud_events(F.fit, 40 - 38 * quick, 11);
nE = numel(ev);
bankA = cell(1, nE);
t0 = tic;
for e = 1:nE
    tb = ev(e).t(1:5:end)'; Gt = ev(e).G(1:5:end, :);
    I = zeros(4000, numel(tb)); Pg = zeros(1, numel(tb)); pk = cell(1, numel(tb));
    parfor j = 1:numel(tb)
        b = bench_curve(reshape(Gt(j, :), 12, 4), 25, cfg); %#ok<PFBNS>
        I(:, j) = b.I; Pg(j) = b.gmpp(2); pk{j} = b.peaks;
    end
    bankA{e} = struct('Vg', Vg, 'I', I, 'Pg', Pg, 'tb', tb, 'pk', {pk}, 'tCh', 3, 'Tstop', ev(e).t(end));
end
say(logf, 'Set A: %d events, curves in %.0f s\n', nE, toc(t0));

%% Set B: pattern steps that move the global peak
PR = random_patterns(300, 1); nR = numel(PR);
Bc = cell(1, nR);
parfor k = 1:nR
    Bc{k} = bench_curve(PR(k).G, 25, cfg); %#ok<PFBNS>
end
rs = RandStream('mt19937ar', 'Seed', 5);
nB = 100 - 96 * quick;
bankB = cell(1, 0);
tries = 0;
while numel(bankB) < nB && tries < 20000
    tries = tries + 1;
    ab = randi(rs, nR, 1, 2);
    if ab(1) == ab(2), continue, end
    a = Bc{ab(1)}; b = Bc{ab(2)};
    if abs(b.gmpp(1) - a.gmpp(1)) <= 0.1 * a.gmpp(1), continue, end
    % Power on curve b near the old operating voltage, at its nearest peak
    [~, in] = min(abs(b.peaks(:, 1) - a.gmpp(1)));
    if b.peaks(in, 2) >= 0.98 * b.gmpp(2), continue, end
    pkc = [repmat({a.peaks}, 1, 1), repmat({b.peaks}, 1, 1)];
    bankB{end+1} = struct('Vg', Vg, 'I', [a.I b.I], 'Pg', [a.gmpp(2) b.gmpp(2)], 'tb', [0 1], ...
                          'pk', {pkc}, 'tCh', 4, 'Tstop', 10, 'ids', ab); %#ok<SAGROW>
end
say(logf, 'Set B: %d pattern steps (from %d draws)\n', numel(bankB), tries);

%% Runs
cases = [ones(nE, 1) (1:nE)'; 2 * ones(numel(bankB), 1) (1:numel(bankB))'];   % [set, index]
job = [];                                  % [case, variant, noise index]
for c = 1:size(cases, 1)
    for v = 1:numel(var)
        for in = 1:numel(nsc)
            job(end+1, :) = [c v in]; %#ok<SAGROW>
        end
    end
end
say(logf, '%d runs\n', size(job, 1));
res = nan(size(job, 1), 4);                % [eta, nSrch, wrong, tRec]
t0 = tic;
parfor r = 1:size(job, 1)
    jb = job(r, :); cs = cases(jb(1), :); v = var(jb(2)); %#ok<PFBNS>
    if cs(1) == 1
        b = bankA{cs(2)}; tk = b.tb; xk = b.tb; xc = b.tb; dxt = 0.005; %#ok<PFBNS>
    else
        b = bankB{cs(2)}; tk = [0 4 4 b.Tstop]; xk = [0 0 1 1]; xc = b.tb; dxt = 1e-6; %#ok<PFBNS>
    end
    p = final_variant(cfg.mppt, v); p.T_rescan = 0; p.rng_seed = 1001; %#ok<PFBNS>
    s = sens_draw(cfg.sens, 300 + 7 * jb(1));
    ns = nsc(jb(3)); %#ok<PFBNS>
    s.nV = s.nV * ns; s.nI = s.nI * ns; s.adc_n = s.adc_n * ns;
    [Pl, Vl, Pr, phl] = static_run_mex(b.Vg, b.I, b.Pg, xc, tk, xk, dxt, b.Tstop, 40, rinA, p, s);
    t = (1:numel(Pl))' * 2e-3;
    res(r, :) = runValues(t, Vl, Pl, Pr, phl, b, cs(1));
end
say(logf, 'Runs done in %.0f s\n', toc(t0));

%% Tables
fid = fopen(fullfile(resDir, 'final_p3n.csv'), 'w');
fprintf(fid, 'set,case,variant,noise_scale,eta_pct,searches,wrong_end,t_recovery_s\n');
for r = 1:size(job, 1)
    cs = cases(job(r, 1), :);
    fprintf(fid, '%s,%d,%s,%d,%.3f,%d,%d,%.3f\n', char('A' + cs(1) - 1), cs(2), vname(var(job(r, 2))), ...
            nsc(job(r, 3)), res(r, :));
end
fclose(fid);
setName = {'A: 40 cloud events', 'B: pattern steps'};
for st = 1:2
    say(logf, '\nSet %s\n%-22s %5s %16s %6s %6s %17s %6s\n', setName{st}, 'Variant', 'Noise', 'Eta mean/min', ...
        'Srch', 'Wrong', 'tRec mean/max s', 'NoRec');
    for v = 1:numel(var)
        for in = 1:numel(nsc)
            m = cases(job(:, 1), 1) == st & job(:, 2) == v & job(:, 3) == in;
            X = res(m, :);
            say(logf, '%-22s %5d %8.3f/%7.3f %6d %6d %8.3f/%8.3f %6d\n', vname(var(v)), nsc(in), mean(X(:, 1)), ...
                min(X(:, 1)), sum(X(:, 2)), sum(X(:, 3)), mean(X(:, 4), 'omitnan'), max(X(:, 4)), sum(isnan(X(:, 4))));
        end
    end
end
save(fullfile(resDir, 'final_p3n.mat'), 'job', 'cases', 'res', 'var', 'nsc');
fclose(logf);

%% Local functions
function x = runValues(t, V, P, Pr, ph, b, set)
% Values of one run (see the help text). Pr is the GMPP power of the bank
% at each log time (static_run.m).
P = P(:); V = V(:); ph = ph(:); Pr = Pr(:);
use = t >= b.tCh;
eta = 100 * sum(P(use)) / sum(Pr(use));
nS  = numel(find(ph == 1 & [true; ph(1:end-1) ~= 1] & use));
cE  = b.pk{end}; [~, ig] = max(cE(:, 2)); last = t > t(end) - 0.3;
[~, in] = min(abs(mean(V(last)) - cE(:, 1)));
wrong = size(cE, 1) > 1 && in ~= ig;
% End of the change: set B the step; set A the last bank step with a change
% of more than 0.1 % of the GMPP power.
tSt = b.tCh;
if set == 1
    dPg = abs(diff(b.Pg)) ./ b.Pg(1:end-1);
    js = find(dPg > 1e-3, 1, 'last');
    if ~isempty(js), tSt = max(b.tCh, b.tb(js + 1)); end
end
low = find(P ./ Pr < 0.99 & t >= tSt, 1, 'last');
if isempty(low)
    tRec = 0;
elseif low < numel(t)
    tRec = t(low + 1) - tSt;
else
    tRec = NaN;
end
x = [eta, nS, wrong, tRec];
end

function say(fid, varargin)
fprintf(varargin{:});
fprintf(fid, varargin{:});
end
