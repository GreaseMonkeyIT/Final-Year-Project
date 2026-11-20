function set_realistic_diodes(mdl, blockNames)
%SET_REALISTIC_DIODES Give diode blocks the values of a 15SQ045 Schottky diode.
%
%   set_realistic_diodes(mdl) sets the three bypass diodes (Diode, Diode1,
%   Diode2) in the loaded model mdl.
%   set_realistic_diodes(mdl, blockNames) sets the diode blocks in the
%   cell array blockNames.
%
%   The 15SQ045 is a 45 V, 15 A Schottky rectifier. Manufacturers sell it
%   as a bypass diode for PV junction boxes. The values come from the
%   Diotec 15SQ045-3G datasheet, at Tj = 25 degC:
%     VF = 0.43 V at IF = 5 A
%     VF = 0.55 V at IF = 15 A
%     IR = 200 uA at VR = 45 V
%
%   The block uses the piecewise-linear diode model. A straight line
%   through the two VF points gives the threshold and the on resistance:
%     Ron = (0.55 - 0.43) / (15 - 5) = 0.012 Ohm
%     Vf  = 0.43 - 5 * 0.012         = 0.37 V
%   The off conductance comes from the leakage: 200e-6 / 45 = 4.4e-6 S.
%   The fit is best from 1 A to 15 A. The bypass currents in this model
%   are 0 A to 7.34 A.
%
%   The model must be loaded. Save the model after the call.

    if nargin < 2
        blockNames = {'Diode', 'Diode1', 'Diode2'};
    end
    for k = 1:numel(blockNames)
        blk = [mdl '/' blockNames{k}];
        set_param(blk, 'ModelType', 'ee.enum.diode.modelType.pwl', ...
            'Vf', '0.37', 'Vf_unit', 'V', ...
            'Ron', '0.012', 'Ron_unit', 'Ohm', ...
            'Goff', '4.4e-6', 'Goff_unit', 'S');
    end
end
