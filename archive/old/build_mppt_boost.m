%BUILD_MPPT_BOOST Add a boost converter to the MPPT.slx PV string model.
%
%   The original model sweeps the string voltage with a controlled voltage
%   source. This script removes that source and connects a boost converter
%   with a resistive load in its place. A duty ramp drives the switch. The
%   ramp moves the PV operating point along the full P-V curve. Replace the
%   ramp with the MPPT controller later.
%
%   Run this script in MATLAB R2024b or later. It is in the folder
%   scripts. The input and output models are in the project folder.
%   Input:  MPPT.slx (the original model, not changed)
%   Output: MPPT_boost.slx
%
%   The output file has the format of the MATLAB release that runs this
%   script. Simulink cannot export Simscape Electrical models to an
%   earlier release. A teammate with R2024b must run this script in
%   R2024b to get a model that R2024b can open.

clear; clc;

projectDir = fileparts(fileparts(mfilename('fullpath')));   % This script is in <project>/scripts
addpath(projectDir, fullfile(projectDir, 'scripts'));
srcFile    = fullfile(projectDir, 'MPPT.slx');
outFile    = fullfile(projectDir, 'MPPT_boost.slx');
buildName  = 'MPPT_boost_build';
buildFile  = fullfile(tempdir, [buildName '.slx']);

% When this flag is true, the bypass diodes and the boost diode get the
% values of a 15SQ045 Schottky diode (see set_realistic_diodes.m). Set
% the flag to false to keep the library default values in the bypass
% diodes (Vf = 0.6 V, Ron = 0.3 Ohm). At 5 A these values give a 2.1 V
% drop, which is more
% than the 2 V cell. The first peak of the P-V curve then goes below 0 V
% and does not show.
USE_REALISTIC_DIODES = true;

%% Converter design values
% A boost converter shows the PV string an input resistance of
% R_load*(1-D)^2. With R_load = 10 Ohm, a duty range of 0 to 0.92 moves
% the operating point from near Voc (about 10 Ohm) to near Isc (0.06 Ohm).
p.fsw    = 20e3;        % Switching frequency [Hz]
p.Ts     = 5e-7;        % Simscape local solver step [s], 100 steps per period
p.Tstop  = 0.6;         % Stop time [s]
p.Dmax   = 0.92;        % Duty at the end of the ramp
p.L      = 150e-6;      % Boost inductor [H], ripple about 18 % at the MPP
p.RL     = 10e-3;       % Inductor series resistance [Ohm]
p.Cin    = 220e-6;      % PV-side capacitor [F], ripple under 1 % of Vpv
p.Cout   = 470e-6;      % Output capacitor [F], ripple under 1 % of Vout
p.Rload  = 10;          % Load resistance [Ohm]
p.Vgate  = 10;          % Gate drive voltage [V], above the 2 V MOSFET threshold

if bdIsLoaded(buildName), close_system(buildName, 0); end
copyfile(srcFile, buildFile, 'f');
load_system(buildFile);
mdl = buildName;

% Keep the design values in the model workspace so that the model file
% carries them.
mws = get_param(mdl, 'ModelWorkspace');
for f = fieldnames(p)'
    assignin(mws, f{1}, p.(f{1}));
end

%% Remove the voltage-source sweep
nl = newline;
oldBlocks = {['Controlled Voltage' nl 'Source'], 'Ramp', ['Simulink-PS' nl 'Converter']};
for k = 1:numel(oldBlocks)
    blk = [mdl '/' oldBlocks{k}];
    deleteBlockLines(blk);
    delete_block(blk);
end


%% Add the power stage
lib.L   = 'fl_lib/Electrical/Electrical Elements/Inductor';
lib.C   = 'fl_lib/Electrical/Electrical Elements/Capacitor';
lib.R   = 'fl_lib/Electrical/Electrical Elements/Resistor';
lib.gnd = 'fl_lib/Electrical/Electrical Elements/Electrical Reference';
lib.vs  = 'fl_lib/Electrical/Electrical Sensors/Voltage Sensor';
lib.Q   = 'ee_lib/Semiconductors & Converters/MOSFET (Ideal, Switching)';
lib.D   = 'ee_lib/Semiconductors & Converters/Diode';
lib.sps = 'nesl_utility/Simulink-PS Converter';
lib.pss = 'nesl_utility/PS-Simulink Converter';

cin  = add_block(lib.C, [mdl '/C_in'],   'Position', [600 440 640 480], 'Orientation', 'down', ...
                 'c', 'Cin', 'r', '0');
ind  = add_block(lib.L, [mdl '/L_boost'], 'Position', [660 395 700 415], ...
                 'l', 'L', 'r', 'RL');
sw   = add_block(lib.Q, [mdl '/S_boost'], 'Position', [730 440 770 490]);
dbo  = add_block(lib.D, [mdl '/D_boost'], 'Position', [790 395 830 415], ...
                 'ModelType', 'ee.enum.diode.modelType.pwl', 'Vf', '0.4', 'Ron', '0.01');
cout = add_block(lib.C, [mdl '/C_out'],  'Position', [860 440 900 480], 'Orientation', 'down', ...
                 'c', 'Cout', 'r', '0');
rl   = add_block(lib.R, [mdl '/R_load'], 'Position', [930 440 970 480], 'Orientation', 'down', ...
                 'R', 'Rload');
gnd  = add_block(lib.gnd, [mdl '/Ground_boost'], 'Position', [780 540 806 565]);
vso  = add_block(lib.vs, [mdl '/Vout Sensor'], 'Position', [1000 440 1040 480]);
pso  = add_block(lib.pss, [mdl '/PS-Simulink Vout'], 'Position', [1070 445 1100 475]);

% The current sensor output terminal is now the converter input node.
cs   = [mdl '/Current Sensor'];
pvIn = pport(cs, 'n');

addConn(mdl, pvIn,               pport(cin, 'p'));
addConn(mdl, pvIn,               pport(ind, 'p'));
addConn(mdl, pport(ind, 'n'),    pport(sw, 'D'));
addConn(mdl, pport(ind, 'n'),    pport(dbo, 'p'));
addConn(mdl, pport(dbo, 'n'),    pport(cout, 'p'));
addConn(mdl, pport(dbo, 'n'),    pport(rl, 'p'));
addConn(mdl, pport(dbo, 'n'),    pport(vso, 'p'));
addConn(mdl, pport(gnd, 'V'),    pport(cin, 'n'));
addConn(mdl, pport(gnd, 'V'),    pport(sw, 'S'));
addConn(mdl, pport(gnd, 'V'),    pport(cout, 'n'));
addConn(mdl, pport(gnd, 'V'),    pport(rl, 'n'));
addConn(mdl, pport(gnd, 'V'),    pport(vso, 'n'));
addConn(mdl, pport(vso, 'V'),    pport(pso, 'in'));

%% Add the PWM gate drive
% The duty ramp stands in for the MPPT controller. The comparator makes
% the gate signal high while the duty is above the 0-to-1 carrier. The
% gate driver gain scales the 0/1 signal to Vgate. The MOSFET block turns
% on above 2 V, so a 1 V signal does not switch it.
duty = add_block('simulink/Sources/Ramp', [mdl '/Duty ramp (replace with MPPT)'], ...
                 'Position', [600 600 630 630], 'slope', 'Dmax/Tstop', 'start', '0', 'InitialOutput', '0');
sat  = add_block('simulink/Discontinuities/Saturation', [mdl '/Duty limit'], ...
                 'Position', [660 600 690 630], 'UpperLimit', '0.95', 'LowerLimit', '0');
car  = add_block('simulink/Sources/Repeating Sequence', [mdl '/Carrier'], ...
                 'Position', [600 660 630 690], 'rep_seq_t', '[0 1/fsw]', 'rep_seq_y', '[0 1]');
cmp  = add_block('simulink/Logic and Bit Operations/Relational Operator', [mdl '/PWM compare'], ...
                 'Position', [720 610 750 680], 'Operator', '>');
dtc  = add_block('simulink/Signal Attributes/Data Type Conversion', [mdl '/Gate to double'], ...
                 'Position', [780 630 810 660], 'OutDataTypeStr', 'double');
gdr  = add_block('simulink/Math Operations/Gain', [mdl '/Gate driver'], ...
                 'Position', [830 630 860 660], 'Gain', 'Vgate');
spg  = add_block(lib.sps, [mdl '/Simulink-PS Gate'], 'Position', [880 635 895 655], ...
                 'Unit', 'V', 'FilteringAndDerivatives', 'zero');

add_line(mdl, 'Duty ramp (replace with MPPT)/1', 'Duty limit/1', 'autorouting', 'smart');
add_line(mdl, 'Duty limit/1',     'PWM compare/1',    'autorouting', 'smart');
add_line(mdl, 'Carrier/1',        'PWM compare/2',    'autorouting', 'smart');
add_line(mdl, 'PWM compare/1',    'Gate to double/1', 'autorouting', 'smart');
add_line(mdl, 'Gate to double/1', 'Gate driver/1',    'autorouting', 'smart');
add_line(mdl, 'Gate driver/1',    'Simulink-PS Gate/1', 'autorouting', 'smart');
addConn(mdl, pport(spg, 'out'), pport(sw, 'G'));

%% Log the signals
% The To Workspace blocks sample once per switching period, as an ADC
% that runs in step with the PWM does.
logs = {'Vpv',  ['PS-Simulink' nl 'Converter'],  [20 400 80 420]
        'Ipv',  ['PS-Simulink' nl 'Converter1'], [20 440 80 460]
        'Ppv',  'Product',                       [20 480 80 500]
        'Vout', 'PS-Simulink Vout',              [1130 450 1190 470]
        'D',    'Duty limit',                    [720 560 780 580]};
for k = 1:size(logs, 1)
    add_block('simulink/Sinks/To Workspace', [mdl '/log_' logs{k,1}], 'Position', logs{k,3}, ...
              'VariableName', logs{k,1}, 'SaveFormat', 'Timeseries', 'SampleTime', '1/fsw');
    add_line(mdl, [logs{k,2} '/1'], ['log_' logs{k,1} '/1'], 'autorouting', 'smart');
end

sc = add_block('simulink/Sinks/Scope', [mdl '/Scope'], 'Position', [1130 560 1170 680], ...
               'NumInputPorts', '4');
add_line(mdl, ['PS-Simulink' nl 'Converter/1'], 'Scope/1', 'autorouting', 'smart');
add_line(mdl, 'Product/1',          'Scope/2', 'autorouting', 'smart');
add_line(mdl, 'PS-Simulink Vout/1', 'Scope/3', 'autorouting', 'smart');
add_line(mdl, 'Duty limit/1',       'Scope/4', 'autorouting', 'smart');

%% Solver settings
% The switch needs a small fixed step. The Simscape local solver runs the
% electrical network at Ts. The Simulink blocks run at the same step.
solver = [mdl '/Solver' nl 'Configuration'];
set_param(solver, 'UseLocalSolver', 'on', 'LocalSolverChoice', 'NE_BACKWARD_EULER_ADVANCER', ...
          'LocalSolverSampleTime', 'Ts', 'DoFixedCost', 'on', 'MaxNonlinIter', '10');
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepAuto', 'FixedStep', 'Ts', ...
          'StopTime', 'Tstop', 'ReturnWorkspaceOutputs', 'on');

%% Diode values
if USE_REALISTIC_DIODES
    set_realistic_diodes(mdl, {'Diode', 'Diode1', 'Diode2', 'D_boost'});
end

if isfile(outFile), delete(outFile); end
save_system(mdl, outFile);
close_system(outFile, 0);
delete(buildFile);
fprintf('Saved %s\n', outFile);

%% Local functions
function h = pport(blk, id)
% Return the handle of the physical port with the given ID on a block.
% Simscape blocks list their port IDs in InternalSimscapePortConfiguration.
% The two converter blocks use "in" and "out" for their Simulink side.
    ph = get_param(blk, 'PortHandles');
    switch id
        case 'in',  h = ph.LConn(1); return
        case 'out', h = ph.RConn(1); return
    end
    cfg = jsondecode(get_param(blk, 'InternalSimscapePortConfiguration'));
    sides = {'Left', 'LConn'; 'Right', 'RConn'};
    for s = 1:2
        list = cfg.(sides{s,1});
        if isempty(list), continue; end
        if isstruct(list), list = num2cell(list); end
        for k = 1:numel(list)
            if strcmp(list{k}.id, id)
                h = ph.(sides{s,2})(k);
                return
            end
        end
    end
    error('build_mppt_boost:port', 'Port "%s" not found on %s.', id, blk);
end

function addConn(mdl, a, b)
% Connect two physical ports.
    add_line(mdl, a, b, 'autorouting', 'smart');
end

function deleteBlockLines(blk)
% Delete the line segments that end on the ports of a block. On a branched
% line, only the branch to this block goes. The rest of the net stays.
    ph = get_param(blk, 'PortHandles');
    ports = [ph.Inport ph.Outport ph.LConn ph.RConn];
    for h = ports
        ln = get_param(h, 'Line');
        if ln > 0, delete_line(ln); end
    end
end
