%GRAPH_MENU Pick one figure of the final review from a numbered list and draw it.
%
%   Type graph_menu in MATLAB. Type the number of a figure. It opens in a
%   figure window, and the list shows again. Type 0 or press Enter to stop.
%   The figures come from the saved results in the folder "results" of the
%   project and need no simulation. Set savePng to true to also save each
%   figure into the folder figures. make_figures.m saves all of them.

savePng = false;
here = fileparts(mfilename('fullpath'));
projectDir = fileparts(fileparts(here));
run(fullfile(projectDir, 'startup.m'));
addpath(fullfile(here, 'plots'), fullfile(projectDir, 'experiments'));
resDir = fullfile(projectDir, 'results');
list = fr_list();
while true
    fprintf('\nFINAL REVIEW FIGURES\n');
    for k = 1:size(list, 1), fprintf('  %2d  %s\n', k, list{k, 2}); end
    fprintf('  %2d  Summary table of all phases\n', size(list, 1) + 1);
    k = input('Number (0 or Enter to stop): ');
    if isempty(k) || k == 0, break, end
    if k == size(list, 1) + 1, disp(fr_summary(resDir)); continue, end
    if k < 1 || k > size(list, 1), continue, end
    fig = list{k, 3}(resDir);
    if savePng, fr_save(fig, fullfile(here, 'figures'), list{k, 1}); end
end
