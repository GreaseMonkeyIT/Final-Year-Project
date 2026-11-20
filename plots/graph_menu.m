%GRAPH_MENU Pick one graph from a numbered menu in the Command Window and draw it.
%
%   Type graph_menu in the project folder. The Command Window shows a
%   numbered list. Type the number of a group, then of a graph, then (for
%   some graphs) of an algorithm, a pattern, or a run. The graph opens in a
%   figure window, and the first list shows again.
%   Type 0 or press Enter to go back. In the first list, this stops the menu.
%
%   The graphs come from the saved results in the folder results, so they
%   take a few seconds and need no simulation:
%     results/pv4x4_sweeps.mat   made by run_pv4x4_sweeps.m
%     results/mppt_results.mat   made by run_po_demo.m
%   The group "Simulate again" runs these two scripts. They also save all
%   the PNG files again.
%
%   To also save each graph as a PNG in the folder results, set savePng to
%   true below. The standard graphs then replace the PNG files of the run
%   scripts. The plot functions are in the folder plots. make_graph.m
%   lists every graph and can draw one without the menu.

savePng = false;    % true: also save each graph to results/<name>.png

projectDir = fileparts(fileparts(mfilename('fullpath')));   % This file is in <project>/plots
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
resDir = fullfile(projectDir, 'results');

while true
    %% Main menu
    group = pickOne('GRAPH MENU', {
        'P-V sweeps of the 4 x 4 array'
        'P&O and INC runs'
        'Simulate again (slow, saves all the PNG files)'}, 'Quit');
    if isempty(group), break; end

    key = ''; arg = [];
    switch group
        case 1
            %% Menu 1: P-V sweeps (results/pv4x4_sweeps.mat)
            S = loadIfThere(fullfile(resDir, 'pv4x4_sweeps.mat'), 'run_pv4x4_sweeps');
            if isempty(S), continue; end
            items = {'Irradiance of each panel, all patterns (fig_patterns)'
                     'P-V curve of each pattern, peaks marked (fig_pv_curves)'
                     'I-V and P-V of P0 to P3 (fig_iv_pv_test)'
                     'All P-V curves on one graph (fig_pv_all)'
                     'One pattern: irradiance, I-V and P-V'
                     'Slide layout: P0 left, P1 to P3 right (fig_slide_pair)'};
            keys  = {'patterns', 'pv_curves', 'iv_pv_test', 'pv_all', 'pattern', 'slide_pair'};
            k = pickOne('P-V SWEEPS', items, 'Back');
            if isempty(k), continue; end
            key = keys{k};
            if strcmp(key, 'pattern')
                labels = arrayfun(@(r) sprintf('%-3s %-30s %d peaks', r.id, r.name, size(r.peaks, 1)), ...
                                  S.res, 'UniformOutput', false);
                j = pickOne('PATTERN', labels, 'Back');
                if isempty(j), continue; end
                arg = S.res(j).id;
            end

        case 2
            %% Menu 2: P&O and INC runs (results/mppt_results.mat)
            M = loadIfThere(fullfile(resDir, 'mppt_results.mat'), 'run_po_demo');
            if isempty(M), continue; end
            items = {'Power reached from start-up, set A (fig_<alg>_startup)'
                     'Operating points on the curves of P1 and P3 (fig_<alg>_trap)'
                     'Winter morning, set C (fig_<alg>_morning)'
                     'P&O and INC side by side (fig_po_vs_inc)'
                     'One run: power, voltage and duty against time'};
            keys  = {'startup', 'trap', 'morning', 'compare', 'run'};
            k = pickOne('P&O AND INC RUNS', items, 'Back');
            if isempty(k), continue; end
            key = keys{k};
            if any(strcmp(key, {'startup', 'trap', 'morning'}))
                j = pickOne('ALGORITHM', M.algName(M.algs), 'Back');
                if isempty(j), continue; end
                arg = M.algs(j);
            elseif strcmp(key, 'run')
                labels = arrayfun(@(r) runLabel(r), M.R, 'UniformOutput', false);
                j = pickOne('RUN', labels, 'Back');
                if isempty(j), continue; end
                arg = j;
            end

        case 3
            %% Menu 3: Simulate again (overwrites the files in results)
            k = pickOne('SIMULATE AGAIN', {
                'All P-V sweeps: run_pv4x4_sweeps (about 1 min)'
                'All P&O and INC runs: run_po_demo (about 5 min, needs the sweeps)'}, 'Back');
            if isempty(k), continue; end
            scripts = {'run_pv4x4_sweeps.m', 'run_po_demo.m'};
            runScript(fullfile(projectDir, 'experiments', scripts{k}));
            continue
    end

    %% Draw the selected graph
    fprintf('Drawing %s ...\n', key);
    [f, name] = make_graph(key, arg);
    f.Visible = 'on';
    f.Name = name;
    drawnow;
    if savePng
        file = fullfile(resDir, [name '.png']);
        exportgraphics(f, file, 'Resolution', 200);
        fprintf('Saved %s\n', file);
    end
end

%% Local functions
function k = pickOne(titleText, items, backText)
% Print a numbered list and read a number. k = [] for 0 or an empty line.
fprintf('\n%s\n', titleText);
for i = 1:numel(items)
    fprintf('  %2d  %s\n', i, items{i});
end
fprintf('   0  %s\n', backText);
while true
    s = strtrim(input('Number: ', 's'));
    k = str2double(s);
    if isempty(s) || k == 0
        k = [];
        return
    end
    if isfinite(k) && k == round(k) && k >= 1 && k <= numel(items)
        return
    end
    fprintf('Type a number from 0 to %d.\n', numel(items));
end
end

function S = loadIfThere(file, script)
% Load a results file. If it does not exist, say which script makes it.
S = [];
if isfile(file)
    S = load(file);
else
    [~, n, e] = fileparts(file);
    fprintf('results/%s%s does not exist. Run %s.m first (menu 3, "Simulate again").\n', n, e, script);
end
end

function s = runLabel(r)
% Menu text for one run of results/mppt_results.mat.
if r.set == 'C'
    s = sprintf('%-4s set C  winter morning (R1 > P1 > P0), start duty %.2f', r.algName, r.Dstart);
else
    s = sprintf('%-4s set %s  %-3s start duty %.2f  %5.1f %% of GMPP', r.algName, r.set, r.id, r.Dstart, r.pct);
end
end

function runScript(file)
% Run a script in this function's workspace. The run scripts start with
% "clear", which then does not clear the variables of the menu.
run(file);
end
