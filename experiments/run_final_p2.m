%RUN_FINAL_P2 Phase 2 of the final tests: the dynamic MPPT tests of EN 50530.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 5).
%
%   Test sequences of EN 50530:2010+A1:2013, Annex B. The values come
%   from a test report that lists them (TUV Rheinland, report CN21VE2D
%   001, section 4.4, pages 15 and 16), not from the standard itself:
%     10 % to 50 % (100 to 500 W/m^2): slopes 0.5, 1, 2, 3, 5, 7, 10, 14,
%       20, 30, 50 W/m^2/s with 2, 2, 3, 4, 6, 8, 10, 10, 10, 10, 10
%       repetitions
%     30 % to 100 % (300 to 1000 W/m^2): slopes 10, 14, 20, 30, 50, 100
%       W/m^2/s, 10 repetitions each
%   Each repetition: ramp up, 10 s dwell, ramp down, 10 s dwell. Each row
%   starts with 300 s of waiting at the low level. The efficiency of a row
%   (Andrean et al., Energies 11, 2018, Eq. (10)) does not count the
%   waiting time. The overall value of each sequence is the mean of its
%   rows, as the standard says.
%   The irradiance scale applies to all the panels: pattern P0 (uniform)
%   and pattern R1 (the shaded panels keep their ratio to the others).
%
%   Part A, static bench (static_run.m, MEX file): the full sequences.
%     Variants: the five searches with the parabolic stage; DIRECT with
%     the local stages 1, 2 and 4; P&O and INC from start-up. 25 degC and
%     45 degC. Sensors on (sens_draw.m, seed 21). Controller values of
%     pv4x4_config.m (restart test and T_rescan = 900 s on).
%   Part B, Simulink (MPPT_4x4.slx): rows 30, 50 and 100 W/m^2/s of the
%     30 % to 100 % sequence, one repetition each, 10 s of waiting. The
%     five searches and the local stages 1, 2 and 4 after DIRECT, P0 and
%     R1, 25 degC, sensors on. Then DIRECT on P0 at 45 degC (part A has all the variants at 45 degC).
%     The static bench runs the same short profiles for comparison.
%
%   Outputs in the folder "results": final_p2.mat, final_p2.csv,
%   final_p2.txt. Run build/build_static_mex.m first.
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
quick = ~isempty(getenv('FINAL_QUICK'));   % Smoke test: few cases, outputs in results/quick
if quick, resDir = fullfile(resDir, 'quick'); if ~isfolder(resDir), mkdir(resDir); end, end
incOnly = ~isempty(getenv('FINAL_INC'));   % Rerun of the INC variants only (fix of 2026-11-22),
sfx = ''; if incOnly, sfx = '_inc'; end    % outputs final_<phase>_inc.*
cfg  = pv4x4_config();
logf = fopen(fullfile(resDir, ['final_p2' sfx '.txt']), 'w');
say(logf, 'run_final_p2.m, %s\n', char(datetime('now')));
pats = shading_patterns(); ids = {pats.id};
seqs = struct('name', {'10-50', '30-100'}, 'lo', {0.1, 0.3}, 'hi', {0.5, 1.0}, ...
              'rows', {[0.5 2; 1 2; 2 3; 3 4; 5 6; 7 8; 10 10; 14 10; 20 10; 30 10; 50 10], ...
                       [10 10; 14 10; 20 10; 30 10; 50 10; 100 10]});
Ts = [25 45]; pid = {'P0', 'R1'};
if quick, for q = 1:2, seqs(q).rows = seqs(q).rows(end, :); seqs(q).rows(2) = 1; end, end
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
locName = {'P&O', 'VS-INC', 'Parabolic', 'INC'};
var = final_variants(true);                % Final comparison (2026-11-23), final_variant.m
if quick, var = var([1 3 6]); end
keep = true(1, numel(var));
if incOnly, keep = [var.loc] == 2 | [var.loc] == 4 | [var.alg] == 2; end
vname = @final_vname;

%% Curve banks: scale 0.08 to 1.02 in steps of 0.0025 for each pattern and temperature
sc = 0.08:0.0025:1.02;
if quick, sc = 0.08:0.02:1.02; end
sim_pool(4);
bank = struct('Vg', {}, 'I', {}, 'Pg', {}, 'sc', {}, 'pk', {});
t0 = tic;
for ip = 1:numel(pid)
    G = pats(strcmp(ids, pid{ip})).G;
    for it = 1:numel(Ts)
        I = zeros(4000, numel(sc)); Pg = zeros(1, numel(sc)); pk = cell(1, numel(sc));
        T = Ts(it);
        parfor j = 1:numel(sc)
            b = bench_curve(sc(j) * G, T, cfg);
            I(:, j) = b.I; Pg(j) = b.gmpp(2); pk{j} = b.peaks;
        end
        bank(ip, it) = struct('Vg', linspace(0, 200, 4000)', 'I', I, 'Pg', Pg, 'sc', sc, 'pk', {pk});
    end
end
say(logf, 'Curve banks: %d curves in %.0f s\n', numel(bank) * numel(sc), toc(t0));

%% Part A: full sequences on the static bench
rinA = [cfg.conv.Rload cfg.conv.RL];
jobs = zeros(0, 6);                        % [variant, pattern, T index, sequence, row, -]
for v = find(keep)
    for ip = 1:2
        for it = 1:2
            for q = 1:2
                for rw = 1:size(seqs(q).rows, 1)
                    jobs(end+1, :) = [v ip it q rw 0]; %#ok<SAGROW>
                end
            end
        end
    end
end
resA = zeros(size(jobs, 1), 4);            % [eta of the row, searches, Lsearch share, duration]
t0 = tic;
parfor r = 1:size(jobs, 1)
    jb = jobs(r, :); v = var(jb(1)); b = bank(jb(2), jb(3)); sq = seqs(jb(4)); %#ok<PFBNS>
    [tk, xk, tEval] = enProfile(sq.lo, sq.hi, sq.rows(jb(5), 1), sq.rows(jb(5), 2), 300);
    p = final_variant(cfg.mppt, v); p.rng_seed = 1001; %#ok<PFBNS>
    s = sens_draw(cfg.sens, 21);
    nLog = 400;                            % 20 ms
    [Pl, ~, Pr, phl] = static_run_mex(b.Vg, b.I, b.Pg, b.sc, tk, xk, 1e-4, tk(end), nLog, rinA, p, s);
    t = (1:numel(Pl))' * nLog * p.Tc;
    use = t > tEval;
    ks = find(phl == 2 & [0; phl(1:end-1)] == 1 & use);   % ends of searches in the evaluated part
    resA(r, :) = [100 * sum(Pl(use)) / sum(Pr(use)), numel(ks), ...
                  100 * sum(Pr(use & phl == 1) - Pl(use & phl == 1)) / sum(Pr(use)), tk(end) - tEval];
end
say(logf, 'Part A: %d rows in %.0f s on 4 workers\n', size(jobs, 1), toc(t0));

fid = fopen(fullfile(resDir, ['final_p2' sfx '.csv']), 'w');
fprintf(fid, 'part,variant,pattern,T_degC,sequence,slope_W_m2_s,repetitions,eta_pct,searches,search_loss_pct\n');
for r = 1:size(jobs, 1)
    jb = jobs(r, :); sq = seqs(jb(4));
    fprintf(fid, 'A,%s,%s,%d,%s,%.1f,%d,%.3f,%d,%.4f\n', vname(var(jb(1))), pid{jb(2)}, Ts(jb(3)), sq.name, ...
            sq.rows(jb(5), 1), sq.rows(jb(5), 2), resA(r, 1:3));
end
say(logf, '\nPart A. Overall dynamic efficiency [%%] (mean of the rows) and searches (sum over the rows)\n');
say(logf, '%-26s %-3s %3s %16s %16s\n', 'Variant', 'Pat', 'T', '10-50 eta/srch', '30-100 eta/srch');
for v = find(keep)
    for ip = 1:2
        for it = 1:2
            e = zeros(1, 4);
            for q = 1:2
                sel = jobs(:, 1) == v & jobs(:, 2) == ip & jobs(:, 3) == it & jobs(:, 4) == q;
                e(2 * q - 1) = mean(resA(sel, 1)); e(2 * q) = sum(resA(sel, 2));
            end
            say(logf, '%-26s %-3s %3d %9.3f/%6d %9.3f/%6d\n', vname(var(v)), pid{ip}, Ts(it), e);
        end
    end
end

%% Part B: Simulink rows 30, 50, 100 W/m^2/s of 30 % to 100 %, one repetition
rowsB = [30 1; 50 1; 100 1];
runsB = struct('mppt', {}, 'Gsched', {}, 'Tstop', {}, 'T', {}, 'sens', {});
keyB = zeros(0, 4);                        % [variant, pattern, T index, row]
for v = find(keep & [var.alg] >= 3)          % Simulink: the searches only
    for ip = 1:2
        for it = 1:2
            if it == 2 && (ip == 2 || v > 1), continue, end
            for rw = 1:3
                keyB(end+1, :) = [v ip it rw]; %#ok<SAGROW>
            end
        end
    end
end
for k = 1:size(keyB, 1)
    kb = keyB(k, :); v = var(kb(1));
    [tk, xk] = enProfile(0.3, 1.0, rowsB(kb(4), 1), 1, 10);
    tg = (0:0.01:tk(end))'; sg = interp1(tk, xk, tg);      % 10 ms steps of the From Workspace block
    G = pats(strcmp(ids, pid{kb(2)})).G(:)';
    m = final_variant(cfg.mppt, v); m.rng_seed = 1001;
    runsB(end+1) = struct('mppt', m, 'Gsched', [tg sg * G], 'Tstop', tk(end), 'T', Ts(kb(3)), ...
                          'sens', sens_draw(cfg.sens, 21)); %#ok<SAGROW>
end
if quick, runsB = runsB(1:2); keyB = keyB(1:2, :); end
[outB, infoB] = bench_sim('MPPT_4x4', runsB, projectDir);
say(logf, '\nPart B: %d Simulink runs, %.0f s simulated, %.0f s wall, MATLAB RAM %.1f GiB\n', numel(runsB), ...
    infoB.simSeconds, infoB.wall, infoB.ramGiB);
resB = nan(size(keyB, 1), 4);              % [eta Simulink, eta static, searches Simulink, searches static]
for k = 1:size(keyB, 1)
    kb = keyB(k, :); v = var(kb(1)); b = bank(kb(2), kb(3)); o = outB(k);
    [tk, xk, tEval] = enProfile(0.3, 1.0, rowsB(kb(4), 1), 1, 10);
    p = final_variant(cfg.mppt, v); p.rng_seed = 1001;
    [Pl, ~, Pr, phl] = static_run_mex(b.Vg, b.I, b.Pg, b.sc, tk, xk, 1e-4, tk(end), 40, rinA, p, sens_draw(cfg.sens, 21));
    ts = (1:numel(Pl))' * 40 * p.Tc; us = ts > tEval;
    eS = 100 * sum(Pl(us)) / sum(Pr(us)); nS = numel(find(phl == 2 & [0; phl(1:end-1)] == 1 & us));
    if ~isempty(o.ErrorMessage), say(logf, 'Run %d: %s\n', k, o.ErrorMessage); resB(k, 2) = eS; continue, end
    t = o.Ppv.Time; P = o.Ppv.Data; ph = squeeze(o.ph.Data); tp = o.ph.Time;
    % GMPP at each log time from the bank (the From Workspace steps of 10 ms).
    sgt = interp1(tk, xk, floor(t / 0.01) * 0.01);
    Pgt = interp1(b.sc, b.Pg, sgt);
    u = t > tEval;
    nSim = numel(find(ph == 2 & [0; ph(1:end-1)] == 1 & tp > tEval));
    resB(k, :) = [100 * sum(P(u)) / sum(Pgt(u)), eS, nSim, nS];
    fprintf(fid, 'B,%s,%s,%d,30-100,%.1f,1,%.3f,%d,NaN\n', vname(v), pid{kb(2)}, Ts(kb(3)), rowsB(kb(4), 1), resB(k, 1), nSim);
end
fclose(fid);
say(logf, '%-26s %-3s %3s %6s %10s %10s %6s %6s\n', 'Variant', 'Pat', 'T', 'Slope', 'Eta Sim', 'Eta stat', 'Srch', 'Srch s');
for k = 1:size(keyB, 1)
    kb = keyB(k, :);
    say(logf, '%-26s %-3s %3d %6d %10.3f %10.3f %6d %6d\n', vname(var(kb(1))), pid{kb(2)}, Ts(kb(3)), rowsB(kb(4), 1), resB(k, :));
end
save(fullfile(resDir, ['final_p2' sfx '.mat']), 'jobs', 'resA', 'keyB', 'resB', 'var', 'seqs', 'Ts', 'pid', 'infoB');
fclose(logf);

%% Local functions
function [tk, xk, tEval] = enProfile(lo, hi, slope, nRep, tWait)
% Irradiance scale against time for one row of EN 50530: tWait at the low
% level, then nRep times (ramp up, 10 s, ramp down, 10 s).
tr = (hi - lo) * 1000 / slope;             % Ramp time [s]
tk = [0 tWait]; xk = [lo lo];
for k = 1:nRep
    t = tk(end);
    tk = [tk, t + tr, t + tr + 10, t + 2 * tr + 10, t + 2 * tr + 20]; %#ok<AGROW>
    xk = [xk, hi, hi, lo, lo]; %#ok<AGROW>
end
tEval = tWait;
end

function y = ternary(c, a, b)
if c, y = a; else, y = b; end
end

function say(fid, varargin)
fprintf(varargin{:});
fprintf(fid, varargin{:});
end
