function startup
%STARTUP Put the folders of the project on the MATLAB path.
%
%   MATLAB runs startup.m when it starts in this folder. The scripts in
%   build/ and experiments/ also run it, so they work from any current
%   folder. Run "startup" by hand after you change the current folder.
%
%   Folders on the path:
%     src/controller   the tracker that the Simulink model calls
%     src/config       pv4x4_config.m and the shading patterns
%     src/plant        static plant helpers
%     build            scripts that make the Simulink models
%     experiments      scripts that run the models and save results
%     plots            figure functions and graph_menu.m
%     models           the Simulink models (models/legacy: team models)

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src', 'controller'), ...
        fullfile(root, 'src', 'config'), ...
        fullfile(root, 'src', 'plant'), ...
        fullfile(root, 'build'), ...
        fullfile(root, 'experiments'), ...
        fullfile(root, 'plots'), ...
        fullfile(root, 'models'), ...
        fullfile(root, 'models', 'legacy'));
end
