function build_pv4x4_sweep(perGroup)
%BUILD_PV4X4_SWEEP Make PV4x4_sweep.slx, the voltage-sweep testbench of the 4 x 4 array.
%
%   build_pv4x4_sweep, or "run build/build_pv4x4_sweep" in the project
%   folder, makes PV4x4_sweep.slx with one irradiance for each panel.
%   build_pv4x4_sweep(true) makes PV4x4_sweep_grp.slx with one irradiance
%   for each bypass-diode group. G is then a 12 x 4 matrix (see
%   add_pv_array and shading_patterns_grp.m).
%
%   The model has the same structure as MPPT.slx. A controlled voltage
%   source ramps the array voltage from 0 V to Voc. The sensors measure
%   the array voltage and current, and two XY graphs plot P-V and I-V.
%   The 16 panels of add_pv_array replace the 3 cells of MPPT.slx.
%
%   The Constant block "Irradiance G" reads the 4 x 4 matrix G (12 x 4 in
%   group mode) from the model workspace. G(r,c) is the panel in row r of
%   string c (see pv4x4_config). To test a shading pattern, change G in
%   the model workspace, or run run_pv4x4_sweeps.m, which runs all the
%   patterns of shading_patterns.m.
%
%   Run this script in MATLAB R2024b or later. It is in the folder
%   scripts. The model is saved in the project folder.
%   Output: PV4x4_sweep.slx. The file has the format of the MATLAB release
%   that runs this script.

if nargin < 1, perGroup = false; end
projectDir = fileparts(fileparts(mfilename('fullpath')));   % This script is in <project>/build
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
mdl     = 'PV4x4_sweep';
cfg     = pv4x4_config();
nRow    = cfg.arr.Nser;                    % Rows of G
if perGroup
    mdl  = [mdl '_grp'];
    nRow = cfg.arr.Nser * cfg.mod.Nbyp;
end
outFile = fullfile(projectDir, 'models', [mdl '.slx']);
nl      = newline;

if bdIsLoaded(mdl), close_system(mdl, 0); end
if isfile(outFile), delete(outFile); end   % Else the old file shadows the new model name.
load_system('ee_lib'); load_system('fl_lib'); load_system('nesl_utility');
new_system(mdl);

%% Model workspace
pv_workspace_vars(mdl, cfg);
ws = get_param(mdl, 'ModelWorkspace');
assignin(ws, 'G',     1000 * ones(nRow, cfg.arr.Npar));
assignin(ws, 'Tstop', cfg.sweep.Tstop);
assignin(ws, 'Vend',  cfg.sweep.Vend);
assignin(ws, 'Tlog',  cfg.sweep.Tlog);

%% Array and irradiance
add_block('simulink/Sources/Constant', [mdl '/Irradiance G'], ...
          'Value', 'G(:)', 'Position', [30 185 110 215]);
arr = add_pv_array(mdl, 'PV Array 4x4', [170 140 290 260], cfg, perGroup);
add_line(mdl, 'Irradiance G/1', 'PV Array 4x4/1');
aph  = get_param(arr, 'PortHandles');
aPos = aph.RConn(1);      % Array "+"
aNeg = aph.RConn(2);      % Array "-"

%% Electrical network
gnd = add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
                [mdl '/Electrical Reference'], 'Position', [520 400 550 430]);
slv = add_block(['nesl_utility/Solver' nl 'Configuration'], [mdl '/Solver Configuration'], ...
                'Position', [400 400 460 430]);
cs  = add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor', [mdl '/Current Sensor'], ...
                'Position', [380 140 420 180]);
vs  = add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', [mdl '/Voltage Sensor'], ...
                'Position', [380 240 420 280], 'Orientation', 'down');
cvs = add_block(['fl_lib/Electrical/Electrical Sources/Controlled Voltage' nl 'Source'], ...
                [mdl '/Controlled Voltage Source'], 'Position', [540 200 580 240], 'Orientation', 'down');

conn(mdl, aPos, pport(cs, 'p'));
conn(mdl, pport(cs, 'n'), pport(cvs, 'p'));
conn(mdl, pport(cvs, 'n'), pport(gnd, 'V'));
conn(mdl, aNeg, pport(gnd, 'V'));
conn(mdl, aPos, pport(vs, 'p'));
conn(mdl, pport(vs, 'n'), pport(gnd, 'V'));
conn(mdl, pport(slv, 'port'), pport(gnd, 'V'));

%% Voltage ramp: 0 V to Vend over the stop time
add_block('simulink/Sources/Ramp', [mdl '/Voltage ramp'], 'Position', [620 90 650 120], ...
          'slope', 'Vend/Tstop', 'start', '0', 'InitialOutput', '0');
spsV = add_block(['nesl_utility/Simulink-PS' nl 'Converter'], [mdl '/Simulink-PS V'], ...
                 'Position', [690 95 720 115], 'Unit', 'V');
add_line(mdl, 'Voltage ramp/1', 'Simulink-PS V/1', 'autorouting', 'smart');
conn(mdl, pport(spsV, 'out'), pport(cvs, cvsInput(cvs)));

%% Measurements, graphs, and logs
psV = add_block(['nesl_utility/PS-Simulink' nl 'Converter'], [mdl '/PS-Simulink V'], ...
                'Position', [460 300 490 320], 'Unit', 'V');
psI = add_block(['nesl_utility/PS-Simulink' nl 'Converter'], [mdl '/PS-Simulink I'], ...
                'Position', [460 40 490 60], 'Unit', 'A');
conn(mdl, pport(vs, 'V'), pport(psV, 'in'));
conn(mdl, pport(cs, 'I'), pport(psI, 'in'));
add_block('simulink/Math Operations/Product', [mdl '/Product'], 'Position', [560 30 590 70]);
add_line(mdl, 'PS-Simulink I/1', 'Product/1', 'autorouting', 'smart');
add_line(mdl, 'PS-Simulink V/1', 'Product/2', 'autorouting', 'smart');

add_block('simulink/Sinks/XY Graph', [mdl '/P-V graph'], 'Position', [700 20 740 60]);
add_line(mdl, 'PS-Simulink V/1', 'P-V graph/1', 'autorouting', 'smart');
add_line(mdl, 'Product/1',       'P-V graph/2', 'autorouting', 'smart');
add_block('simulink/Sinks/XY Graph', [mdl '/I-V graph'], 'Position', [700 300 740 340]);
add_line(mdl, 'PS-Simulink V/1', 'I-V graph/1', 'autorouting', 'smart');
add_line(mdl, 'PS-Simulink I/1', 'I-V graph/2', 'autorouting', 'smart');

logs = {'Vpv', 'PS-Simulink V', [460 350 520 370]
        'Ipv', 'PS-Simulink I', [560 90 620 110]
        'Ppv', 'Product',       [640 150 700 170]};
for k = 1:size(logs, 1)
    add_block('simulink/Sinks/To Workspace', [mdl '/log_' logs{k,1}], 'Position', logs{k,3}, ...
              'VariableName', logs{k,1}, 'SaveFormat', 'Timeseries', 'SampleTime', 'Tlog');
    add_line(mdl, [logs{k,2} '/1'], ['log_' logs{k,1} '/1'], 'autorouting', 'smart');
end

%% Solver
% The network has no capacitors or inductors, so each instant is a DC
% operating point. The variable-step solver of MPPT.slx stays.
set_param(mdl, 'StopTime', 'Tstop', 'Solver', 'ode23t', 'MaxStep', '1e-3', ...
          'ReturnWorkspaceOutputs', 'on');

save_system(mdl, outFile);
close_system(mdl, 0);
fprintf('Saved %s\n', outFile);
end

%% Local functions
function conn(sys, a, b)
% Connect two physical ports.
add_line(sys, a, b, 'autorouting', 'smart');
end

function id = cvsInput(blk)
% Return the ID of the physical signal input of the controlled source.
cfg = jsondecode(get_param(blk, 'InternalSimscapePortConfiguration'));
for side = {'Left', 'Right'}
    list = cfg.(side{1});
    if isstruct(list), list = num2cell(list); end
    for k = 1:numel(list)
        if strcmp(list{k}.type, 'input'), id = list{k}.id; return; end
    end
end
error('build_pv4x4_sweep:port', 'No signal input on %s.', getfullname(blk));
end
