%RUN_PV4X4_SWEEPS Sweep the 4 x 4 array for each shading pattern and plot the curves.
%
%   The script runs PV4x4_sweep.slx once for each pattern of
%   shading_patterns.m. For each pattern it finds the local peaks of the
%   P-V curve and the global peak (GMPP).
%
%   Outputs in the folder "results":
%     pv4x4_sweeps.mat      curves, peaks, and GMPP of each pattern
%                           (run_po_demo.m reads the GMPP values)
%     pv4x4_peaks.csv       one row per pattern
%     fig_patterns.png      the irradiance of each panel, for each pattern
%     fig_pv_curves.png     the P-V curve of each pattern, peaks marked
%     fig_pv_all.png        all nine P-V curves on one graph
%     fig_iv_pv_test.png    I-V and P-V of the test patterns P0 to P3
%
%   Colors: P0 (uniform) is the reference, dashed dark gray. P1 to R5 use
%   the eight series colors of plot_style in order. A pattern has the
%   same color in fig_pv_all.png and fig_iv_pv_test.png.
%
%   Run scripts/build_pv4x4_sweep.m first. Run time: about 1 min.

clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));   % This script is in <project>/experiments
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
resDir = fullfile(projectDir, 'results');
if ~isfolder(resDir), mkdir(resDir); end

mdl  = 'PV4x4_sweep';
cfg  = pv4x4_config();
pats = shading_patterns();
st   = plot_style();
load_system(fullfile(projectDir, 'models', [mdl '.slx']));

%% Run one sweep for each pattern
nP = numel(pats);
in(1:nP) = Simulink.SimulationInput(mdl);
for k = 1:nP
    in(k) = in(k).setVariable('G', pats(k).G, 'Workspace', mdl);
end
out = sim(in, 'ShowProgress', 'off');

res = struct('id', {}, 'name', {}, 'G', {}, 'cause', {}, 'V', {}, 'I', {}, 'P', {}, ...
             'Voc', {}, 'Isc', {}, 'peaks', {}, 'gmpp', {});
for k = 1:nP
    V = out(k).Vpv.Data; I = out(k).Ipv.Data; P = out(k).Ppv.Data;
    keep = I > 0;                 % Keep 0 V to Voc
    V = V(keep); I = I(keep); P = P(keep);
    pk = find(islocalmax(P, 'MinProminence', 0.002 * max(P)));   % 0.2 %: keeps shallow real peaks
    [~, j] = max(P);
    r = struct('id', pats(k).id, 'name', pats(k).name, 'G', pats(k).G, ...
               'cause', pats(k).cause, 'V', V, 'I', I, 'P', P, ...
               'Voc', V(end), 'Isc', I(1), 'peaks', [V(pk) P(pk)], 'gmpp', [V(j) P(j)]);
    res(k) = r;
end
save(fullfile(resDir, 'pv4x4_sweeps.mat'), 'res', 'cfg');

%% Table
fprintf('\n%-4s %-32s %6s %6s %5s  %-10s  %s\n', 'ID', 'Pattern', 'Voc', 'Isc', 'Peaks', 'GMPP', 'All peaks (V / W)');
fid = fopen(fullfile(resDir, 'pv4x4_peaks.csv'), 'w');
fprintf(fid, 'id,pattern,Voc_V,Isc_A,n_peaks,gmpp_V,gmpp_W,gmpp_pct_of_uniform,peaks_V_W\n');
Puni = res(1).gmpp(2);
for k = 1:nP
    r = res(k);
    pkStr = strjoin(arrayfun(@(a, b) sprintf('%.1f/%.0f', a, b), r.peaks(:,1), r.peaks(:,2), ...
                             'UniformOutput', false), '  ');
    fprintf('%-4s %-32s %6.1f %6.2f %5d  %4.0f W @ %4.1f V  %s\n', r.id, r.name, r.Voc, r.Isc, ...
            size(r.peaks, 1), r.gmpp(2), r.gmpp(1), pkStr);
    fprintf(fid, '%s,"%s",%.2f,%.2f,%d,%.2f,%.1f,%.1f,"%s"\n', r.id, r.name, r.Voc, r.Isc, ...
            size(r.peaks, 1), r.gmpp(1), r.gmpp(2), 100 * r.gmpp(2) / Puni, pkStr);
end
fclose(fid);

%% Figures (the plot functions are in the folder plots)
figs = {'fig_patterns',   plot_patterns(res, st)
        'fig_pv_curves',  plot_pv_curves(res, cfg, st)
        'fig_iv_pv_test', plot_iv_pv_test(res, cfg, st)
        'fig_pv_all',     plot_pv_all(res, cfg, st)};
for k = 1:size(figs, 1)
    exportgraphics(figs{k,2}, fullfile(resDir, [figs{k,1} '.png']), 'Resolution', 200);
end
close all
fprintf('\nSaved results in %s\n', resDir);
