function build_static_mex()
%BUILD_STATIC_MEX Make the MEX file of static_run.m with MATLAB Coder.
%
%   build_static_mex makes static_run_mex in the folder src/plant. The
%   static tests of docs/notes/final_test_plan.md (phases 1b, 4 and 5)
%   call it: one run of 4 s takes milliseconds in place of seconds.
%   The types come from pv4x4_config.m. Make the MEX file again after a
%   change of the controller code, or of the size of a field of cfg.mppt
%   or cfg.sens (for example the number of PSO particles).
%   Needs MATLAB Coder and a C compiler (mex -setup C).

projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
cfg = pv4x4_config();
outDir = fullfile(projectDir, 'src', 'plant');
mc = coder.config('mex');
mc.IntegrityChecks = false;
mc.ResponsivenessChecks = false;
% static_run(Vg, Ib, Pgb, xc, tk, xk, dxt, Tstop, nLog, rinA, p, s)
vcol = coder.typeof(0, [8000 1], [1 0]);           % Voltage grid, up to 8000 points
bank = coder.typeof(0, [8000 4000], [1 1]);        % Curve bank, up to 4000 curves
row  = coder.typeof(0, [1 4000], [0 1]);
sch  = coder.typeof(0, [1 20000], [0 1]);          % Schedule, up to 20000 points
args = {vcol, bank, row, row, sch, sch, 0, 0, 0, [0 0], cfg.mppt, cfg.sens};
codegen('static_run', '-config', mc, '-args', args, '-d', fullfile(projectDir, 'codegen', 'static_run'), ...
        '-o', fullfile(outDir, 'static_run_mex'));
fprintf('Saved %s\n', fullfile(outDir, ['static_run_mex.' mexext]));
end
