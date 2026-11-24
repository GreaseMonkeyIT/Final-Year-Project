%MAKE_FIGURES Draw all figures and the summary table of the final review.
%
%   Run in MATLAB from any folder. The script reads the results of the
%   final tests in the folder "results" of the project and writes the PNG
%   files and summary.csv into reports/final_review/figures. It runs no
%   simulation. graph_menu.m draws one figure at a time.

here = fileparts(mfilename('fullpath'));
projectDir = fileparts(fileparts(here));
run(fullfile(projectDir, 'startup.m'));
addpath(fullfile(here, 'plots'), fullfile(projectDir, 'experiments'));
resDir = fullfile(projectDir, 'results');
outDir = fullfile(here, 'figures');
list = fr_list();
for k = 1:size(list, 1)
    try
        fig = list{k, 3}(resDir);
        fr_save(fig, outDir, list{k, 1});
        close(fig);
        fprintf('%-22s saved\n', list{k, 1});
    catch ME
        fprintf('%-22s FAILED: %s\n', list{k, 1}, ME.message);
    end
end
T = fr_summary(resDir, fullfile(outDir, 'summary.csv'));
disp(T);
