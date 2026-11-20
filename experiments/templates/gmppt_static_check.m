%GMPPT_STATIC_CHECK Run the global searches on the static curves and compare with Python.
%
%   Task T2 of HANDOFF_ideas_B_C.md. The script finds porting errors
%   before the slower Simulink runs. It uses no Simulink.
%
%   1. A static plant gives the steady-state operating point for a duty
%      D: the point where the I-V curve of results/pv4x4_sweeps.mat meets
%      the line I = V / R_in(D) (pv_static_point.m). This is the same as
%      Plant.at_duty in crosscheck/algos.py.
%   2. gmppt_search.m runs the search (mppt.alg = 3 to 8) on this
%      plant, one probe for each call (gmppt_static_run.m). MPPT_4x4.slx runs the same code
%      inside mppt_controller.m.
%   3. After the hand-over, the P&O of algos.po_local runs for nPO steps.
%   4. The script compares each run with the log of algos.py on the same
%      curves (crosscheck/simulink_curves_runs.json, made by
%      "python run_simulink_curves.py" in the folder crosscheck): the
%      number of search probes, the duty of every probe, the hand-over
%      duty, and the final power.
%
%   Two converter maps:
%     'ideal'  R_in = R (1 - D)^2 / D^2, as algos.py. The comparison
%              with Python uses this map.
%     'RL'     R_in = (R (1 - D)^2 + RL) / D^2. The settled points of
%              MPPT_4x4.slx follow this map (run_settling_check.m). These
%              runs predict the duty sequence of the Simulink runs.
%
%   Outputs in the folder results:
%     gmppt_static_check.csv, gmppt_static_check.mat
%
%   Run run_pv4x4_sweeps.m first. Run time: a few seconds.

clear; clc;
projectDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % This script is in <project>/experiments/templates
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
resDir = fullfile(projectDir, 'results');
S   = load(fullfile(resDir, 'pv4x4_sweeps.mat'));
sw  = S.res;
cfg = pv4x4_config();
p0  = cfg.mppt;
cv  = cfg.conv;
J   = jsondecode(fileread(fullfile(projectDir, 'archive', '2026-11-21_post_midreview', 'python', 'simulink_curves_runs.json')));

algs  = [3 4 5 6 7 8];
names = {'DIRECT', 'Idea B', 'Idea C', 'DIRECT paper', 'PSO', 'Idea B refined'};
maps  = {'ideal', 'RL'};
nPO   = 60;                % P&O steps after the hand-over, as algos.po_local
rin   = {@(D) cv.Rload * (1 - D)^2 / D^2, ...
         @(D) (cv.Rload * (1 - D)^2 + cv.RL) / D^2};

%% Runs
R = struct('map', {}, 'alg', {}, 'method', {}, 'id', {}, 'D', {}, 'V', {}, 'I', {}, ...
           'nSearch', {}, 'Dhand', {}, 'final', {}, 'gmpp', {});
for m = 1:numel(maps)
    for a = 1:numel(algs)
        p = p0;
        p.alg = algs(a);
        for k = 1:numel(sw)
            g = sw(k);
            r = gmppt_static_run(g, p, rin{m}, nPO);
            r.map = maps{m}; r.alg = algs(a); r.method = names{a}; r.id = g.id;
            R(end+1) = orderfields(r, R); %#ok<SAGROW>
        end
    end
end

%% Comparison with Python (ideal map)
fprintf('Search probes / final %% of the GMPP / hand-over duty. MATLAB (ideal map) against Python.\n\n');
fprintf('%-7s %-3s %16s %16s %8s %8s %11s %9s\n', 'Method', 'Pat', 'MATLAB', 'Python', ...
        'probes', 'duties', 'max |dD|', 'final');
rows = struct('method', {});
nBad = 0;
for k = find(strcmp({R.map}, 'ideal'))
    r  = R(k);
    py = J.(matlab.lang.makeValidName(r.method)).(r.id);
    Dpy = [py.log.D]';
    nPy = py.summary.glob;
    sameN = (r.nSearch == nPy);
    n  = min(numel(r.D), numel(Dpy));
    dD = max(abs(r.D(1:n) - Dpy(1:n)));
    sameD = sameN && numel(r.D) == numel(Dpy) && dD < 1e-9;
    dFinal = 100 * (r.final - py.summary.final);
    nBad = nBad + ~sameD;
    fprintf('%-7s %-3s %3d / %5.1f / %.4f %3d / %5.1f / %.4f %8s %8s %11.2e %+8.4f\n', r.method, r.id, ...
            r.nSearch, 100 * r.final, r.Dhand, nPy, 100 * py.summary.final, py.handover, ...
            okText(sameN), okText(sameD), dD, dFinal);
    j = numel(rows) + 1;
    rows(j).method = string(r.method); rows(j).pattern = string(r.id);
    rows(j).probes_matlab = r.nSearch; rows(j).probes_python = nPy;
    rows(j).handover_matlab = r.Dhand; rows(j).handover_python = py.handover;
    rows(j).final_pct_matlab = 100 * r.final; rows(j).final_pct_python = 100 * py.summary.final;
    rows(j).max_abs_duty_diff = dD; rows(j).same_sequence = sameD;
end
fprintf('\n%d of %d runs differ from Python.\n', nBad, numel(rows));

%% Ideal map against the RL map (the converter of MPPT_4x4.slx)
fprintf('\nSearch probes / final %% of the GMPP / hand-over duty, with the RL map:\n\n');
fprintf('| Method | %s |\n', strjoin({sw.id}, ' | '));
fprintf('|---%s|\n', repmat('|---', 1, numel(sw)));
for a = 1:numel(algs)
    cells = strings(1, numel(sw));
    for k = 1:numel(sw)
        rI = R(strcmp({R.map}, 'ideal') & [R.alg] == algs(a) & strcmp({R.id}, sw(k).id));
        rR = R(strcmp({R.map}, 'RL')    & [R.alg] == algs(a) & strcmp({R.id}, sw(k).id));
        cells(k) = sprintf('%d / %.1f / %.4f%s', rR.nSearch, 100 * rR.final, rR.Dhand, ...
                           ifelse(isequal(rI.D(1:rI.nSearch), rR.D(1:rR.nSearch)), '', ' *'));
        j = find([rows.method] == names{a} & [rows.pattern] == sw(k).id);
        rows(j).probes_RL = rR.nSearch; rows(j).handover_RL = rR.Dhand;
        rows(j).final_pct_RL = 100 * rR.final;
        rows(j).same_search_as_ideal = isequal(rI.D(1:rI.nSearch), rR.D(1:rR.nSearch));
    end
    fprintf('| %s | %s |\n', names{a}, strjoin(cells, ' | '));
end
fprintf('\n* The search duties differ from the ideal map.\n');

T = struct2table(rows(:));
writetable(T, fullfile(resDir, 'gmppt_static_check.csv'));
save(fullfile(resDir, 'gmppt_static_check.mat'), 'R', 'T', 'cfg', 'nPO');
fprintf('\nSaved results in %s\n', resDir);

%% Local functions
function s = okText(c)
if c, s = 'same'; else, s = 'DIFFER'; end
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
