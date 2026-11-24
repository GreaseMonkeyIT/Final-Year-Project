%RUN_FINAL_P5 Phase 5 of the final tests: sensitivity, on the static bench.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 8). One
%   value changes at a time from the values of pv4x4_config.m:
%     sensors   noise scale (all noise values times 0, 1, 3, 10, 30), ADC
%               bits (10, 12, 14, 16), static errors (times 0, 1, 3)
%     T         cell temperature 15, 25, 45, 65 degC
%     stage     p.chk_T, p.chk_d, p.chk_db, p.chk_ramp, p.par_kmax, p.par_tol
%     ceiling   p.eps_c and p.tau (Idea B and Idea C only)
%   Test sets:
%     S  the nine patterns and the first 100 patterns of each random kind
%        of random_patterns.m, 4 s from start-up, sensors on (3 seeds).
%        Values: mean and lowest final power, rate of wrong peaks.
%     D  EN 50530, 30 % to 100 %, slope 30 W/m^2/s, 3 repetitions, 60 s
%        of waiting, P0 and R1, sensors on. Value: dynamic efficiency.
%   The five searches use the parabolic stage. PSO and GWO use one seed
%   of their generator for each sensor seed.
%
%   Outputs in the folder "results": final_p5.mat, final_p5.csv
%   FINAL_QUICK set in the environment: a smoke test with a few cases,
%   outputs in results/quick.


clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
quick = ~isempty(getenv('FINAL_QUICK'));   % Smoke test: few cases, outputs in results/quick
if quick, resDir = fullfile(resDir, 'quick'); if ~isfolder(resDir), mkdir(resDir); end, end
cfg = pv4x4_config();
rinA = [cfg.conv.Rload cfg.conv.RL];
P9 = shading_patterns(); PR = random_patterns(300, 1);
kinds = {PR.kind}; kIdx = [PR.k];
Gs = [arrayfun(@(p) {p.G}, P9), arrayfun(@(p) {p.G}, PR(kIdx <= 100))];
pats = shading_patterns(); ids = {pats.id};

% Factors: {name, field, values}. Field 'noise', 'bits', 'err', 'T' are bench values.
F = {'noise scale', 'noise', [0 1 3 10 30]
     'ADC bits', 'bits', [10 12 14 16]
     'static error scale', 'err', [0 1 3]
     'T [degC]', 'T', [15 25 45 65]
     'chk_T [s]', 'chk_T', [0.25 0.5 1 2 4]
     'chk_d', 'chk_d', [0.001 0.002 0.004]
     'chk_db', 'chk_db', [0 1e-4 1e-3]
     'chk_ramp', 'chk_ramp', [3e-4 1e-3 3e-3]
     'par_kmax', 'par_kmax', [1 2 3 5]
     'par_tol', 'par_tol', [0.0005 0.001 0.002]
     'eps_c', 'eps_c', [0.01 0.02 0.05]
     'tau', 'tau', [0.005 0.01 0.02]};
if quick, Gs = Gs(1:3); F = F([1 5 11], :); for f = 1:3, F{f, 3} = F{f, 3}(1); end, end
sim_pool(4);

% Curves for each temperature.
Tset = unique([25, F{strcmp(F(:, 2), 'T'), 3}]);
CB = cell(numel(Gs), numel(Tset));
t0 = tic;
parfor q = 1:numel(Gs) * numel(Tset)
    [ig, it] = ind2sub([numel(Gs) numel(Tset)], q);
    CB{q} = bench_curve(Gs{ig}, Tset(it), cfg); %#ok<PFBNS>
end
fprintf('%d curves in %.0f s\n', numel(CB), toc(t0));
% Banks for the ramp at each temperature.
sc = 0.25:0.0025:1.02;
if quick, sc = 0.25:0.02:1.03; end
RB = cell(2, numel(Tset)); pn = {'P0', 'R1'};
for ip = 1:2
    G = pats(strcmp(ids, pn{ip})).G;
    for it = 1:numel(Tset)
        I = zeros(4000, numel(sc)); Pg = zeros(1, numel(sc)); T = Tset(it);
        parfor j = 1:numel(sc), b = bench_curve(sc(j) * G, T, cfg); I(:, j) = b.I; Pg(j) = b.gmpp(2); end
        RB{ip, it} = struct('Vg', linspace(0, 200, 4000)', 'I', I, 'Pg', Pg, 'sc', sc);
    end
end
tr = 700 / 30; tk = [0 60]; xk = [0.3 0.3];
for k = 1:3, t = tk(end); tk = [tk t + tr, t + tr + 10, t + 2 * tr + 10, t + 2 * tr + 20]; xk = [xk 1 1 0.3 0.3]; end %#ok<AGROW>

rows = {};
fid = fopen(fullfile(resDir, 'final_p5.csv'), 'w');
fprintf(fid, 'factor,value,search,S_pct_end_mean,S_pct_end_min,S_wrong_pct,D_eta_P0,D_eta_R1\n');
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
t0 = tic;
for f = 1:size(F, 1)
    for val = F{f, 3}
        for a = 3:7
            if any(strcmp(F{f, 2}, {'eps_c', 'tau'})) && ~ismember(a, [4 5]), continue, end
            p = final_variant(cfg.mppt, struct('alg', a, 'loc', 3 + 2 * (a == 3))); p.T_rescan = 0;   % DIRECT as in its paper (2026-11-23)
            s = cfg.sens; T = 25; ns = 1; es = 1;
            switch F{f, 2}
                case 'noise', ns = val;
                case 'bits', s.bits = val;
                case 'err', es = val;
                case 'T', T = val;
                otherwise, p.(F{f, 2}) = val;
            end
            it = find(Tset == T);
            % Set S.
            nG = numel(Gs); R = zeros(nG * 3, 2);
            parfor q = 1:nG * 3
                [ig, sd] = ind2sub([nG 3], q);
                b = CB{ig, it}; %#ok<PFBNS>
                ss = sens_draw(s, 1000 * ig + sd);
                ss.eV = ss.eV * es; ss.oV = ss.oV * es; ss.eI = ss.eI * es; ss.oI = ss.oI * es;
                ss.adc_gain = ss.adc_gain * es; ss.adc_off = ss.adc_off * es; ss.adc_inl = ss.adc_inl * es;
                ss.nV = ss.nV * ns; ss.nI = ss.nI * ns; ss.adc_n = ss.adc_n * ns;
                pp = p; pp.rng_seed = 1000 + sd;
                [Pl, Vl, ~, phl] = static_run_mex(b.Vg, b.I, b.gmpp(2), 0, 0, 0, 1e-6, 4, 40, rinA, pp, ss);
                t = (1:numel(Pl))' * 2e-3;
                m = bench_metrics(t, Vl, Pl, phl, struct('ic', ones(size(t)), ...
                    'curves', struct('gmpp', b.gmpp, 'peaks', b.peaks), 't0', 0.06));
                R(q, :) = [100 * mean(Pl(t > 3.7)) / b.gmpp(2), m.wrongEnd];
            end
            % Set D.
            eD = zeros(1, 2);
            for ip = 1:2
                b = RB{ip, it};
                ss = sens_draw(s, 21);
                ss.eV = ss.eV * es; ss.oV = ss.oV * es; ss.eI = ss.eI * es; ss.oI = ss.oI * es;
                ss.adc_gain = ss.adc_gain * es; ss.adc_off = ss.adc_off * es; ss.adc_inl = ss.adc_inl * es;
                ss.nV = ss.nV * ns; ss.nI = ss.nI * ns; ss.adc_n = ss.adc_n * ns;
                pp = p; pp.T_rescan = 900;
                [Pl, ~, Pr] = static_run_mex(b.Vg, b.I, b.Pg, b.sc, tk, xk, 1e-4, tk(end), 400, rinA, pp, ss);
                t = (1:numel(Pl))' * 0.02; u = t > 60;
                eD(ip) = 100 * sum(Pl(u)) / sum(Pr(u));
            end
            v = [mean(R(:, 1)), min(R(:, 1)), 100 * mean(R(:, 2)), eD];
            fprintf(fid, '%s,%g,%s,%.3f,%.3f,%.2f,%.3f,%.3f\n', F{f, 1}, val, algName{a}, v);
            fprintf('%-18s %8g %-7s S %.3f/%.3f wrong %.2f %%, D %.3f/%.3f (%.0f s)\n', F{f, 1}, val, algName{a}, v, toc(t0));
            rows(end+1, :) = {F{f, 1}, val, a, v}; %#ok<SAGROW>
        end
    end
end
fclose(fid);
save(fullfile(resDir, 'final_p5.mat'), 'rows', 'F');
