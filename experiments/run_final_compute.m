%RUN_FINAL_COMPUTE Execution time and compute energy of the controller.
%
%   Made on 2026-11-22 for the final tests (docs/notes/final_test_plan.md).
%   For each variant and pattern, one closed-loop run of 4 s on the static
%   bench (sensors off, T_rescan = 0) records V and I in each control
%   sample. ctrl_loop.m (MEX file, made here with MATLAB Coder) then calls
%   mppt_controller.m on this series and measures the time inside the
%   compiled code. The same inputs give the same decisions, so the time is
%   that of the closed-loop run.
%   Values of each variant (mean over the patterns):
%     us_dec      mean time of one decision call [us] (the call at the end
%                 of an MPPT period), timer cost subtracted
%     us_srchdec  the same for the decisions of the search phase
%     us_p99      99th percentile of the decision calls [us]
%     us_sample   mean time of one call over all samples [us]
%     t_srch      length of the start-up search [s]
%     E_run       compute energy of the run of 4 s on this PC [J] = time
%                 of all calls x P_core
%     E_search    compute energy of the decisions of the search [J]
%   P_core: the PC runs the MEX file on one core. The CPU (AMD Ryzen 9
%   8940HX, 16 cores) has a default TDP of 55 W, so this script takes
%   55 W / 16 = 3.4 W for one busy core. This is an estimate, not a
%   measurement. The times are those of this PC, not of the target
%   controller (TMS320F28379D). The ratios between the variants carry
%   over better than the absolute values.
%
%   Outputs in the folder "results": final_compute.mat, .csv, .txt.
%   FINAL_QUICK set in the environment: one pattern and two variants,
%   outputs in results/quick.


clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
quick = ~isempty(getenv('FINAL_QUICK'));
if quick, resDir = fullfile(resDir, 'quick'); if ~isfolder(resDir), mkdir(resDir); end, end
cfg = pv4x4_config();
logf = fopen(fullfile(resDir, 'final_compute.txt'), 'w');
say(logf, 'run_final_compute.m, %s\n', char(datetime('now')));
Pcore = 55 / 16;                           % [W], see the help text

%% MEX file of ctrl_loop.m
mc = coder.config('mex');
mc.IntegrityChecks = false;
mc.ResponsivenessChecks = false;
vec = coder.typeof(0, [200000 1], [1 0]);
codegen('ctrl_loop', '-config', mc, '-args', {vec, vec, cfg.mppt, 0}, ...
        '-d', fullfile(projectDir, 'codegen', 'ctrl_loop'), '-o', fullfile(tempdir, 'ctrl_loop_mex'));
addpath(tempdir);

%% Variants and patterns
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
locName = {'P&O', 'VS-INC', 'Parabolic', 'INC'};
var = final_variants(true);                % Final comparison (2026-11-23), final_variant.m
pats = shading_patterns(); pid = {'P0', 'P1', 'P3', 'R1'};
if quick, var = var([1 3]); pid = pid(1); end
rinA = [cfg.conv.Rload cfg.conv.RL];
nrep = 20 - 18 * quick;
res = nan(numel(var), numel(pid), 8);
% [us_dec, us_dec_search, us_p99, us_sample, t_srch, decisions, E_run J, E_search J]
for ip = 1:numel(pid)
    b = bench_curve(pats(strcmp({pats.id}, pid{ip})).G, 25, cfg);
    for v = 1:numel(var)
        p = final_variant(cfg.mppt, var(v)); p.T_rescan = 0; p.rng_seed = 1001;
        [Pl, Vl, ~, phl] = static_run_mex(b.Vg, b.I, b.gmpp(2), 0, 0, 0, 1e-6, 4, 1, rinA, p, cfg.sens);
        V = Vl(:); I = Pl(:) ./ max(Vl(:), 1e-9);
        % A unique offset of 1 nV in each sample (1e-11 of the voltage, far
        % below each threshold) makes the average of each period differ
        % from the last one, so ctrl_loop.m finds every decision. On the
        % static bench a held point repeats the same average exactly.
        V = V + 1e-9 * sin((1:numel(V))');
        [tAll, tDec, tOv, nDec, tCall, phDec] = ctrl_loop_mex(V, I, p, nrep);
        n = numel(V);
        ov = tOv / (nrep * nDec);              % Timer cost of one decision call [s]
        tc = max(tCall - ov, 0);
        sr = phDec == 1;                       % Decisions that end in the search phase
        res(v, ip, :) = [1e6 * (tDec - tOv) / (nrep * nDec), 1e6 * mean(tc(sr)), 1e6 * prctile(tc, 99), ...
                         1e6 * tAll / (nrep * n), nnz(phl == 1) * p.Tc, nDec, Pcore * tAll / nrep, ...
                         Pcore * sum(tc(sr))];
    end
end

%% Table
fid = fopen(fullfile(resDir, 'final_compute.csv'), 'w');
fprintf(fid, 'variant,us_per_decision,us_per_search_decision,us_p99_decision,us_per_sample,t_search_s,decisions,E_run_4s_J,E_search_J\n');
say(logf, '\nPC: AMD Ryzen 9 8940HX, one core, P_core = %.1f W (estimate). %d passes of each run.\n', Pcore, nrep);
say(logf, 'Mean over the patterns %s. Times of one call [us], energies [J].\n', strjoin(pid, ', '));
say(logf, '%-22s %9s %10s %9s %10s %8s %6s %11s %11s\n', 'Variant', 'us/dec', 'us/srchdec', 'us p99', 'us/sample', ...
    't srch s', 'dec', 'E run 4 s', 'E search');
for v = 1:numel(var)
    nm = final_vname(var(v));
    x = squeeze(mean(res(v, :, :), 2, 'omitnan'))';
    fprintf(fid, '%s,%.4f,%.4f,%.4f,%.5f,%.3f,%.0f,%.4e,%.4e\n', nm, x);
    say(logf, '%-22s %9.4f %10.4f %9.4f %10.5f %8.3f %6.0f %11.3e %11.3e\n', nm, x);
end
fclose(fid);
save(fullfile(resDir, 'final_compute.mat'), 'var', 'pid', 'res', 'Pcore', 'nrep');
fclose(logf);

function say(fid, varargin)
fprintf(varargin{:});
fprintf(fid, varargin{:});
end
