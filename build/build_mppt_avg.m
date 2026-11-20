%BUILD_MPPT_AVG Put an Average-Value DC-DC Converter into the team model.
%
%   MPPT_2.slx uses the switching Buck-Boost Converter block with a fixed
%   50 % pulse. This script removes that block and the Pulse Generator.
%   It connects the Average-Value DC-DC Converter (buck-boost mode) in the
%   same place. A duty ramp drives the DutyCycle input directly, so the
%   model has no PWM and no switching. Replace the ramp with the MPPT
%   controller later.
%
%   The script also makes these changes:
%     - It gives the bypass diodes the 15SQ045 values
%       (see set_realistic_diodes.m).
%     - It adds the input capacitor C_in across the PV terminals.
%       MPPT_2.slx has no input capacitor.
%     - It logs Vpv, Ipv, Ppv, Vout, and D to the workspace.
%
%   Run this script in MATLAB R2024b or later. It is in the folder
%   scripts. The input and output models are in the project folder.
%   Input:  MPPT_2.slx (the team model, not changed)
%   Output: MPPT_avg.slx
%
%   The output file has the format of the MATLAB release that runs this
%   script. Simulink cannot export Simscape Electrical models to an
%   earlier release. A teammate with R2024b must run this script in
%   R2024b to get a model that R2024b can open.

clear; clc;

projectDir = fileparts(fileparts(mfilename('fullpath')));   % This script is in <project>/build
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
srcFile    = fullfile(projectDir, 'models', 'legacy', 'MPPT_2.slx');
outFile    = fullfile(projectDir, 'models', 'MPPT_avg.slx');
buildName  = 'MPPT_avg_build';
buildFile  = fullfile(tempdir, [buildName '.slx']);

%% Design values
% The buck-boost converter shows the PV string an input resistance of
% R_load*((1-D)/D)^2. With the 1 Ohm load of MPPT_2.slx, a duty ramp from
% 0 to 0.95 moves the operating point from Voc to near Isc. The MPP
% (about 0.93 Ohm with the 15SQ045 diodes) is near D = 0.51.
p.Tstop  = 1;           % Stop time [s]. The ramp is slow, so each point is close to steady state.
p.Dmax   = 0.95;        % Duty at the end of the ramp
p.L      = 150e-6;      % Converter inductor [H]. The block default of 1 uH is too small.
p.RL     = 10e-3;       % Inductor series resistance [Ohm]
p.Cout   = 470e-6;      % Output capacitor [F]. The block default of 0.1 uF is too small.
p.Cin    = 220e-6;      % PV-side capacitor [F]

if bdIsLoaded(buildName), close_system(buildName, 0); end
copyfile(srcFile, buildFile, 'f');
load_system(buildFile);
mdl = buildName;
nl  = newline;

mws = get_param(mdl, 'ModelWorkspace');
for f = fieldnames(p)'
    assignin(mws, f{1}, p.(f{1}));
end

%% Remove the switching converter and the pulse generator
oldConv  = [mdl '/Buck-Boost Converter'];
oldPulse = [mdl '/Pulse Generator'];
convPos  = get_param(oldConv, 'Position');
pulsePos = get_param(oldPulse, 'Position');
deleteBlockLines(oldConv);
deleteBlockLines(oldPulse);
delete_block(oldConv);
delete_block(oldPulse);

%% Add the averaged converter in the same place
conv = add_block(sprintf('ee_lib/Semiconductors &\nConverters/Converters/Average-Value DC-DC\nConverter'), ...
                 [mdl '/Average-Value DC-DC Converter'], 'Position', convPos);
set_param(conv, 'implementation_option', 'ee.enum.converters.implementation.averageValue', ...
                'converter_type', 'ee.enum.converters.dcdctype.buckboost', ...
                'control_option', 'ee.enum.converters.controlinput.dutycycle', ...
                'Lf', 'L', 'Rl', 'RL', 'Cf', 'Cout', 'Rc', '1e-3');

gnd  = [mdl '/Electrical Reference'];
cs   = [mdl '/Current Sensor'];
res  = [mdl '/Resistor'];
spsD = [mdl '/Simulink-PS' nl 'Converter4'];

addConn(mdl, pport(cs, 'n'),   pport(conv, 'p1'));
addConn(mdl, pport(gnd, 'V'),  pport(conv, 'n1'));
addConn(mdl, pport(conv, 'p2'), pport(res, 'p'));
addConn(mdl, pport(conv, 'n2'), pport(res, 'n'));

% The input capacitor holds the PV voltage. It sets the settling time of
% the PV operating point after a duty change.
cin = add_block('fl_lib/Electrical/Electrical Elements/Capacitor', [mdl '/C_in'], ...
                'Position', convPos + [-90 60 -110 80], 'Orientation', 'down', 'c', 'Cin', 'r', '0');
addConn(mdl, pport(cs, 'n'),  pport(cin, 'p'));
addConn(mdl, pport(gnd, 'V'), pport(cin, 'n'));

%% Drive the duty input
% The ramp stands in for the MPPT controller. The Simulink-PS converter
% treats the duty as piecewise constant, as a controller output is.
set_param(spsD, 'Name', 'Simulink-PS Duty');
spsD = [mdl '/Simulink-PS Duty'];
set_param(spsD, 'Unit', '1', 'FilteringAndDerivatives', 'zero');
add_block('simulink/Sources/Ramp', [mdl '/Duty ramp (replace with MPPT)'], 'Position', pulsePos, ...
          'slope', 'Dmax/Tstop', 'start', '0', 'InitialOutput', '0');
add_line(mdl, 'Duty ramp (replace with MPPT)/1', 'Simulink-PS Duty/1', 'autorouting', 'smart');
addConn(mdl, pport(spsD, 'out'), pport(conv, 'DutyCycle'));

%% Measure the output voltage
resPos = get_param(res, 'Position');
vso = add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', [mdl '/Vout Sensor'], ...
                'Position', resPos + [70 0 70 0]);
pso = add_block('nesl_utility/PS-Simulink Converter', [mdl '/PS-Simulink Vout'], ...
                'Position', resPos + [140 5 120 -5]);
addConn(mdl, pport(res, 'p'), pport(vso, 'p'));
addConn(mdl, pport(res, 'n'), pport(vso, 'n'));
addConn(mdl, pport(vso, 'V'), pport(pso, 'in'));

%% Log the signals
logs = {'Vpv',  ['PS-Simulink' nl 'Converter']
        'Ipv',  ['PS-Simulink' nl 'Converter1']
        'Ppv',  'Product'
        'Vout', 'PS-Simulink Vout'
        'D',    'Duty ramp (replace with MPPT)'};
for k = 1:size(logs, 1)
    src = get_param([mdl '/' logs{k,2}], 'Position');
    add_block('simulink/Sinks/To Workspace', [mdl '/log_' logs{k,1}], ...
              'Position', src + [0 60 30 50], ...
              'VariableName', logs{k,1}, 'SaveFormat', 'Timeseries', 'SampleTime', '5e-4');
    add_line(mdl, [logs{k,2} '/1'], ['log_' logs{k,1} '/1'], 'autorouting', 'smart');
end

%% Diodes and solver
set_realistic_diodes(mdl);

% The model has no switching, so the variable-step solver of MPPT_2.slx
% stays. A smaller maximum step resolves the L-C dynamics.
set_param(mdl, 'StopTime', 'Tstop', 'MaxStep', '1e-4', 'ReturnWorkspaceOutputs', 'on');

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
    error('build_mppt_avg:port', 'Port "%s" not found on %s.', id, blk);
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
