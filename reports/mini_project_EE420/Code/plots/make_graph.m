function [f, name] = make_graph(key, arg)
%MAKE_GRAPH Draw one graph from the saved results. No simulation.
%
%   [f, name] = make_graph(key) and [f, name] = make_graph(key, arg)
%   return the figure f (not visible) and its file name, without ".png".
%   graph_menu.m calls this function. You can also call it directly.
%
%   From results/pv4x4_sweeps.mat (made by run_pv4x4_sweeps.m):
%     'patterns'     irradiance of each panel, for each pattern
%     'pv_curves'    P-V curve of each pattern, peaks marked
%     'iv_pv_test'   I-V and P-V of P0 to P3
%     'pv_all'       all P-V curves on one graph
%     'slide_pair'   slide layout: P0 (left) and P1 to P3 (right), I-V above P-V
%     'pattern'      irradiance, I-V, and P-V of one pattern. arg = pattern ID, for example 'P3'.
%   From results/mppt_results.mat (made by run_po_demo.m):
%     'startup'      power reached from start-up, set A.        arg = 1 (P&O) or 2 (INC)
%     'trap'         operating points on the curves of P1 and P3. arg = 1 or 2
%     'morning'      winter morning, set C.                       arg = 1 or 2
%     'compare'      P&O and INC side by side
%     'run'          power, voltage, and duty of one run.         arg = index into R
%
%   Example: f = make_graph('pattern', 'R1'); f.Visible = 'on';

if nargin < 2, arg = []; end
projectDir = fileparts(fileparts(mfilename('fullpath')));   % This file is in <project>/plots
resDir = fullfile(projectDir, 'results');
st = plot_style();

S = loadResults(fullfile(resDir, 'pv4x4_sweeps.mat'), 'run_pv4x4_sweeps');
res = S.res;
ids = {res.id};
gm  = @(id) res(strcmp(ids, id));

switch key
    case 'patterns',   f = plot_patterns(res, st);            name = 'fig_patterns';
    case 'pv_curves',  f = plot_pv_curves(res, S.cfg, st);    name = 'fig_pv_curves';
    case 'iv_pv_test', f = plot_iv_pv_test(res, S.cfg, st);   name = 'fig_iv_pv_test';
    case 'pv_all',     f = plot_pv_all(res, S.cfg, st);       name = 'fig_pv_all';
    case 'slide_pair', f = plot_slide_pair(res, S.cfg, st);   name = 'fig_slide_pair';
    case 'pattern'
        if ~any(strcmp(ids, arg))
            error('make_graph:pattern', 'Pattern "%s" is not in pv4x4_sweeps.mat.', string(arg));
        end
        f = plot_pattern_one(res, arg, S.cfg, st);            name = ['fig_pattern_' arg];
    otherwise
        M = loadResults(fullfile(resDir, 'mppt_results.mat'), 'run_po_demo');
        R = M.R;
        algFile = {'po', 'inc'};
        algCol  = st.series([1 2], :);            % P&O blue, INC orange, as in run_po_demo.m
        if any(strcmp(key, {'startup', 'trap', 'morning'})) && ~any(M.algs == arg)
            error('make_graph:alg', 'Give arg = 1 (P&O) or 2 (INC). mppt_results.mat has algorithms %s.', ...
                  mat2str(M.algs));
        end
        switch key
            case 'startup'
                f = plot_startup(R([R.alg] == arg), M.algName{arg}, algCol(arg,:), gm, st);
                name = sprintf('fig_%s_startup', algFile{arg});
            case 'trap'
                f = plot_trap(R([R.alg] == arg), M.algName{arg}, gm, st);
                name = sprintf('fig_%s_trap', algFile{arg});
            case 'morning'
                f = plot_morning(R([R.set] == 'C' & [R.alg] == arg), M.algName{arg}, algCol(arg,:), ...
                                 gm, st, M.tM, M.morning);
                name = sprintf('fig_%s_morning', algFile{arg});
            case 'compare'
                f = plot_compare(R, M.algs, M.algName, algCol, gm, st, M.tM, M.morning);
                name = 'fig_po_vs_inc';
            case 'run'
                r = R(arg);
                f = plot_run_one(r, gm, st, algCol(r.alg,:), M.tM, M.morning);
                name = sprintf('fig_run_%s_%s_%s', algFile{r.alg}, r.set, strrep(r.id, '>', '_'));
            otherwise
                error('make_graph:key', 'Unknown graph "%s". Type "help make_graph" for the list.', key);
        end
end
end

function S = loadResults(file, script)
if ~isfile(file)
    [~, n, e] = fileparts(file);
    error('make_graph:noResults', 'results/%s%s does not exist. Run %s.m first.', n, e, script);
end
S = load(file);
end
