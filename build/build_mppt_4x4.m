function build_mppt_4x4(perGroup)
%BUILD_MPPT_4X4 Make MPPT_4x4.slx: the 4 x 4 array, the buck-boost converter, and the tracker.
%
%   build_mppt_4x4, or "run build/build_mppt_4x4" in the project folder,
%   makes MPPT_4x4.slx with one irradiance for each panel. Each row of
%   Gsched is then [t, G(:)'] with a 4 x 4 matrix G.
%   build_mppt_4x4(true) makes MPPT_4x4_grp.slx with one irradiance for
%   each bypass-diode group. G is then a 12 x 4 matrix (see add_pv_array
%   and shading_patterns_grp.m).
%
%   The power stage is the same as in MPPT_avg.slx: the Average-Value
%   DC-DC Converter in buck-boost mode, an input capacitor C_in, and a
%   resistive load. The 16 panels of add_pv_array replace the 3 cells.
%   The tracker (mppt_controller.m: P&O, INC, DIRECT, Ideas B and C)
%   replaces the duty ramp. It sets the duty directly, with no voltage
%   loop.
%
%   Structure:
%     Irradiance schedule  From Workspace block. It reads Gsched from the
%                          model workspace: each row is [t, G(:)'], and
%                          the value holds until the next row.
%     PV Array 4x4         see add_pv_array
%     Controller           subsystem with inputs Vpv and Ipv and output D.
%                          It holds only the MATLAB Function block "MPPT",
%                          which calls mppt_controller.m at the control
%                          sample time mppt.Tc. This subsystem is the part
%                          to copy into a real-time model for the dSPACE
%                          MicroLabBox. It has no Simscape blocks and no
%                          logging blocks.
%   Logs (to the variable out): Vpv, Ipv, Ppv, D, Vout, ph (phase: 0 wait,
%   1 global search, 2 tracking) and np (probes of the global search)
%   every Tlog, and Vm and Im (the averages of each decision) every
%   mppt.Tmppt. A search probe lasts mppt.Tsearch, so its Vm and Im show
%   in more than one log point.
%
%   Run this script in MATLAB R2024b or later. It is in the folder
%   scripts. The model is saved in the project folder.
%   The model calls mppt_controller.m, so keep the project folder as the
%   current folder (or on the path) when you run the model.
%   Output: MPPT_4x4.slx, in the format of the MATLAB release that runs
%   this script.

if nargin < 1, perGroup = false; end
projectDir = fileparts(fileparts(mfilename('fullpath')));   % This script is in <project>/build
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
mdl     = 'MPPT_4x4';
cfg     = pv4x4_config();
nG      = cfg.arr.Nser * cfg.arr.Npar;     % Irradiance inputs
if perGroup
    mdl = [mdl '_grp'];
    nG  = nG * cfg.mod.Nbyp;
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
c  = cfg.conv;
assignin(ws, 'L',       c.L);
assignin(ws, 'RL',      c.RL);
assignin(ws, 'Cout',    c.Cout);
assignin(ws, 'Rc',      c.Rc);
assignin(ws, 'Cin',     c.Cin);
assignin(ws, 'Cin_esr', c.Cin_esr);
assignin(ws, 'Rload',   c.Rload);
assignin(ws, 'mppt',    cfg.mppt);
assignin(ws, 'Gsched',  [0, 1000 * ones(1, nG)]);
assignin(ws, 'Tstop',   2);
assignin(ws, 'Tlog',    5e-4);

%% Array and irradiance
add_block('simulink/Sources/From Workspace', [mdl '/Irradiance schedule'], ...
          'Position', [20 185 120 215], 'VariableName', 'Gsched', 'Interpolate', 'off', ...
          'OutputAfterFinalValue', 'Holding final value', 'SampleTime', '0');
arr = add_pv_array(mdl, 'PV Array 4x4', [170 140 290 260], cfg, perGroup);
add_line(mdl, 'Irradiance schedule/1', 'PV Array 4x4/1');
aph  = get_param(arr, 'PortHandles');
aPos = aph.RConn(1);
aNeg = aph.RConn(2);

%% Power stage
gnd  = add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
                 [mdl '/Electrical Reference'], 'Position', [560 420 590 450]);
slv  = add_block(['nesl_utility/Solver' nl 'Configuration'], [mdl '/Solver Configuration'], ...
                 'Position', [440 420 500 450]);
csPV = add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor', [mdl '/Ipv Sensor'], ...
                 'Position', [350 140 390 180]);
vsPV = add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', [mdl '/Vpv Sensor'], ...
                 'Position', [350 250 390 290], 'Orientation', 'down');
cin  = add_block('fl_lib/Electrical/Electrical Elements/Capacitor', [mdl '/C_in'], ...
                 'Position', [450 250 480 290], 'Orientation', 'down', 'c', 'Cin', 'r', 'Cin_esr');
conv = add_block(sprintf('ee_lib/Semiconductors &\nConverters/Converters/Average-Value DC-DC\nConverter'), ...
                 [mdl '/Average-Value DC-DC Converter'], 'Position', [560 170 660 290]);
set_param(conv, 'implementation_option', 'ee.enum.converters.implementation.averageValue', ...
                'converter_type', 'ee.enum.converters.dcdctype.buckboost', ...
                'control_option', 'ee.enum.converters.controlinput.dutycycle', ...
                'Lf', 'L', 'Rl', 'RL', 'Cf', 'Cout', 'Rc', 'Rc');
res  = add_block('fl_lib/Electrical/Electrical Elements/Resistor', [mdl '/R_load'], ...
                 'Position', [760 210 790 250], 'Orientation', 'down', 'R', 'Rload');
vso  = add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', [mdl '/Vout Sensor'], ...
                 'Position', [850 210 890 250], 'Orientation', 'down');

conn(mdl, aPos, pport(csPV, 'p'));
conn(mdl, pport(csPV, 'n'), pport(conv, 'p1'));
conn(mdl, pport(csPV, 'n'), pport(cin, 'p'));
conn(mdl, pport(csPV, 'n'), pport(vsPV, 'p'));
conn(mdl, pport(cin, 'n'),  pport(gnd, 'V'));
conn(mdl, pport(vsPV, 'n'), pport(gnd, 'V'));
conn(mdl, aNeg, pport(gnd, 'V'));
conn(mdl, pport(conv, 'n1'), pport(gnd, 'V'));
conn(mdl, pport(conv, 'p2'), pport(res, 'p'));
conn(mdl, pport(conv, 'n2'), pport(res, 'n'));
conn(mdl, pport(res, 'p'), pport(vso, 'p'));
conn(mdl, pport(res, 'n'), pport(vso, 'n'));
conn(mdl, pport(slv, 'port'), pport(gnd, 'V'));

%% Measurements
psV = add_block(['nesl_utility/PS-Simulink' nl 'Converter'], [mdl '/PS-Simulink Vpv'], ...
                'Position', [400 330 430 350], 'Unit', 'V');
psI = add_block(['nesl_utility/PS-Simulink' nl 'Converter'], [mdl '/PS-Simulink Ipv'], ...
                'Position', [400 70 430 90], 'Unit', 'A');
psO = add_block(['nesl_utility/PS-Simulink' nl 'Converter'], [mdl '/PS-Simulink Vout'], ...
                'Position', [930 220 960 240], 'Unit', 'V');
conn(mdl, pport(vsPV, 'V'), pport(psV, 'in'));
conn(mdl, pport(csPV, 'I'), pport(psI, 'in'));
conn(mdl, pport(vso, 'V'),  pport(psO, 'in'));
add_block('simulink/Math Operations/Product', [mdl '/Ppv'], 'Position', [480 60 510 100]);
add_line(mdl, 'PS-Simulink Ipv/1', 'Ppv/1', 'autorouting', 'smart');
add_line(mdl, 'PS-Simulink Vpv/1', 'Ppv/2', 'autorouting', 'smart');

%% Controller (the part for the real-time target)
ctl = [mdl '/Controller'];
add_block('built-in/Subsystem', ctl, 'Position', [480 470 600 560]);
add_block('simulink/Sources/In1',  [ctl '/Vpv'], 'Position', [30 40 60 54]);
add_block('simulink/Sources/In1',  [ctl '/Ipv'], 'Position', [30 90 60 104]);
add_block('simulink/Sinks/Out1',   [ctl '/D'],   'Position', [330 30 360 44]);
add_block('simulink/Sinks/Out1',   [ctl '/Vm'],  'Position', [330 70 360 84]);
add_block('simulink/Sinks/Out1',   [ctl '/Im'],  'Position', [330 110 360 124]);
add_block('simulink/Sinks/Out1',   [ctl '/ph'],  'Position', [330 150 360 164]);
add_block('simulink/Sinks/Out1',   [ctl '/np'],  'Position', [330 190 360 204]);
mf = add_block('simulink/User-Defined Functions/MATLAB Function', [ctl '/MPPT'], ...
               'Position', [130 30 250 210]);
fcfg = get_param(mf, 'MATLABFunctionConfiguration');
fcfg.FunctionScript = sprintf([ ...
    'function [D, Vm, Im, ph, np] = MPPT(Vpv, Ipv, mppt)\n' ...
    '%% One call per control sample. The algorithm is in mppt_controller.m.\n' ...
    '[D, Vm, Im, ph, np] = mppt_controller(Vpv, Ipv, mppt);\n']);
fcfg.UpdateMethod = 'Discrete';
fcfg.SampleTime   = 'mppt.Tc';
% The argument "mppt" is a parameter (the struct in the model workspace),
% not an input port.
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', getfullname(mf));
dat   = find(chart, '-isa', 'Stateflow.Data', 'Name', 'mppt');
dat.Scope = 'Parameter';
add_line(ctl, 'Vpv/1', 'MPPT/1', 'autorouting', 'smart');
add_line(ctl, 'Ipv/1', 'MPPT/2', 'autorouting', 'smart');
add_line(ctl, 'MPPT/1', 'D/1',   'autorouting', 'smart');
add_line(ctl, 'MPPT/2', 'Vm/1',  'autorouting', 'smart');
add_line(ctl, 'MPPT/3', 'Im/1',  'autorouting', 'smart');
add_line(ctl, 'MPPT/4', 'ph/1',  'autorouting', 'smart');
add_line(ctl, 'MPPT/5', 'np/1',  'autorouting', 'smart');

add_line(mdl, 'PS-Simulink Vpv/1', 'Controller/1', 'autorouting', 'smart');
add_line(mdl, 'PS-Simulink Ipv/1', 'Controller/2', 'autorouting', 'smart');

% A real controller writes the new duty to the PWM one sample after it
% reads the ADC. The delay also breaks the algebraic loop between the
% controller and the network.
add_block('simulink/Discrete/Unit Delay', [mdl '/Computation delay'], ...
          'Position', [630 485 665 515], 'SampleTime', 'mppt.Tc', 'InitialCondition', 'mppt.Dstart');
spsD = add_block(['nesl_utility/Simulink-PS' nl 'Converter'], [mdl '/Simulink-PS Duty'], ...
                 'Position', [700 490 730 510], 'Unit', '1', 'FilteringAndDerivatives', 'zero');
add_line(mdl, 'Controller/1', 'Computation delay/1', 'autorouting', 'smart');
add_line(mdl, 'Computation delay/1', 'Simulink-PS Duty/1', 'autorouting', 'smart');
conn(mdl, pport(spsD, 'out'), pport(conv, 'DutyCycle'));

%% Logs
logs = {'Vpv',  'PS-Simulink Vpv/1',  'Tlog',       [460 360 520 380]
        'Ipv',  'PS-Simulink Ipv/1',  'Tlog',       [480 110 540 130]
        'Ppv',  'Ppv/1',              'Tlog',       [560 60 620 80]
        'Vout', 'PS-Simulink Vout/1', 'Tlog',       [990 220 1050 240]
        'D',    'Controller/1',       'Tlog',       [700 540 760 560]
        'Vm',   'Controller/2',       'mppt.Tmppt', [700 580 760 600]
        'Im',   'Controller/3',       'mppt.Tmppt', [700 620 760 640]
        'ph',   'Controller/4',       'Tlog',       [700 660 760 680]
        'np',   'Controller/5',       'Tlog',       [700 700 760 720]};
for k = 1:size(logs, 1)
    add_block('simulink/Sinks/To Workspace', [mdl '/log_' logs{k,1}], 'Position', logs{k,4}, ...
              'VariableName', logs{k,1}, 'SaveFormat', 'Timeseries', 'SampleTime', logs{k,3});
    add_line(mdl, logs{k,2}, ['log_' logs{k,1} '/1'], 'autorouting', 'smart');
end

%% Solver
set_param(mdl, 'StopTime', 'Tstop', 'Solver', 'ode23t', 'MaxStep', '1e-4', ...
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
