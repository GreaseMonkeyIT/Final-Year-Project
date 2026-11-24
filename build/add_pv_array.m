function blk = add_pv_array(sys, name, pos, cfg, perGroup)
%ADD_PV_ARRAY Add a series-parallel PV array subsystem to a Simulink model.
%
%   blk = add_pv_array(sys, name, pos, cfg) adds the subsystem sys/name at
%   the position pos. cfg comes from pv4x4_config. The array has
%   cfg.arr.Nser panels in series in each string and cfg.arr.Npar strings
%   in parallel.
%
%   blk = add_pv_array(sys, name, pos, cfg, true) gives each bypass-diode
%   group its own irradiance input (see "Ports").
%
%   Each panel has cfg.mod.Nbyp groups of cells in series. Each group is
%   one Solar Cell block with pv_Ngrp cells and one bypass diode across it.
%   This is the layout of a real panel: the E325P72 has 72 cells in three
%   groups of 24, with one bypass diode for each group.
%
%   Ports of the subsystem:
%     In 1 (Simulink)  G, a vector of irradiances [W/m^2] in the order G(:).
%                      Panel mode (perGroup = false, the default): G is
%                      Nser x Npar. G(r,c) is the panel in row r of string
%                      c. All the groups of a panel get the same irradiance.
%                      Group mode (perGroup = true): G is (Nser*Nbyp) x Npar.
%                      G((r-1)*Nbyp + g, c) is group g of the panel in row r
%                      of string c. Row 1 is the top group of the top panel.
%     + and - (physical)  the array terminals.
%
%   The panel and diode blocks read the variables pv_Ngrp, pv_Isc,
%   pv_Voc, pv_n, pv_Rs, pv_Ir0, pv_TIPH1, pv_EG, pv_TXIS1, pv_TRS1,
%   pv_Tmeas, pv_T, byp_Vf, byp_Ron, and byp_Goff. The caller
%   must put these variables in the model workspace (see pv_workspace_vars).
%   The number of groups is part of the structure: to change it, change
%   cfg.mod.Nbyp and build the model again.
%
%   Block names, for the panel in row r of string c:
%     PV_rc_g  cell group g (g = 1 is at the "+" end of the panel)
%     D_rc_g   bypass diode of group g
%     G_rc     irradiance input of the panel (panel mode)
%     G_rc_g   irradiance input of group g (group mode)
%   With one group per panel, the names are PV_rc and D_rc.

if nargin < 5, perGroup = false; end
nl   = newline;
Ns   = cfg.arr.Nser;
Np   = cfg.arr.Npar;
Nb   = cfg.mod.Nbyp;
blk  = [sys '/' name];
dy   = 110;                     % Vertical pitch of the groups in a panel
rowH = 60 + Nb*dy;              % Vertical pitch of the panels
nG   = Ns*Np;                   % Irradiance inputs
if perGroup, nG = Ns*Np*Nb; end

add_block('built-in/Subsystem', blk, 'Position', pos);
add_block('simulink/Sources/In1', [blk '/G'], 'Position', [20 400 50 414]);

dmx = add_block('simulink/Signal Routing/Demux', [blk '/Demux'], ...
                'Outputs', num2str(nG), 'Position', [110 40 115 40 + rowH*Ns]);
add_line(blk, 'G/1', 'Demux/1');

pp = add_block('nesl_utility/Connection Port', [blk '/+'], 'Side', 'Right', ...
               'Position', [260 + 300*Np, 30, 290 + 300*Np, 50]);
pn = add_block('nesl_utility/Connection Port', [blk '/-'], 'Side', 'Right', ...
               'Position', [260 + 300*Np, 60 + rowH*Ns, 290 + 300*Np, 80 + rowH*Ns]);

for c = 1:Np
    x = 300*c;
    for r = 1:Ns
        y0 = 60 + rowH*(r-1);
        id = sprintf('%d%d', r, c);

        if ~perGroup
            sps = addIrradiance(blk, ['G_' id], [x-70 y0-35 x-40 y0-15]);
            k = r + Ns*(c-1);                     % Index in G(:)
            add_line(blk, sprintf('Demux/%d', k), sprintf('G_%s/1', id), 'autorouting', 'smart');
        end

        for g = 1:Nb
            y = y0 + dy*(g-1);
            if Nb == 1
                sfx = id;
            else
                sfx = sprintf('%s_%d', id, g);
            end
            pv = add_block('ee_lib/Sources/Solar Cell', [blk '/PV_' sfx], ...
                           'Position', [x y x+60 y+70], 'Orientation', 'down');
            set_param(pv, 'prm', 'ee.enum.sources.solar_cell_prm.datasheet', ...
                      'Isc', 'pv_Isc', 'Voc', 'pv_Voc', 'Ir0', 'pv_Ir0', ...
                      'ec', 'pv_n', 'Rs', 'pv_Rs', 'N_series', 'pv_Ngrp');
            % Temperature (added 2026-11-21). TFIXED stays a compile-time
            % parameter: as a run-time parameter it made MPPT_4x4.slx 60 %
            % slower (31.3 s against 19.6 s for 2 s of P3, 2026-11-21). A
            % new pv_T thus compiles the network again (a few seconds).
            set_param(pv, 'TIPH1', 'pv_TIPH1', 'EG', 'pv_EG', 'TXIS1', 'pv_TXIS1', ...
                      'TRS1', 'pv_TRS1', 'Tmeas', 'pv_Tmeas', 'TFIXED', 'pv_T');

            d = add_block(sprintf('ee_lib/Semiconductors &\nConverters/Diode'), [blk '/D_' sfx], ...
                          'Position', [x+110 y+15 x+140 y+55], 'Orientation', 'up');
            set_param(d, 'ModelType', 'ee.enum.diode.modelType.pwl', ...
                      'Vf', 'byp_Vf', 'Ron', 'byp_Ron', 'Goff', 'byp_Goff');

            if perGroup
                % One irradiance signal for each group.
                sps = addIrradiance(blk, ['G_' sfx], [x-70 y+25 x-40 y+45]);
                k = (r-1)*Nb + g + Ns*Nb*(c-1);   % Index in G(:)
                add_line(blk, sprintf('Demux/%d', k), sprintf('G_%s/1', sfx), 'autorouting', 'smart');
            end
            % Panel mode: one irradiance signal drives all the groups of the panel.
            conn(blk, pport(sps, 'out'), pport(pv, 'Ir'));

            % Bypass diode: anode to the group "-", cathode to the group "+".
            conn(blk, pport(d, 'p'), pport(pv, 'n'));
            conn(blk, pport(d, 'n'), pport(pv, 'p'));

            % Series connection: groups in the panel, panels in the string.
            if r == 1 && g == 1
                conn(blk, pport(pp, 'port'), pport(pv, 'p'));
            else
                conn(blk, pport(prev, 'n'), pport(pv, 'p'));
            end
            if r == Ns && g == Nb
                conn(blk, pport(pv, 'n'), pport(pn, 'port'));
            end
            prev = pv;
        end
    end
end
set_param(dmx, 'Position', [110 40 115 40 + rowH*Ns]);
end

function sps = addIrradiance(blk, name, pos)
% Simulink-PS converter for one irradiance input, with the filter G_tau.
sps = add_block(['nesl_utility/Simulink-PS' newline 'Converter'], [blk '/' name], 'Position', pos);
set_param(sps, 'Unit', 'W/m^2', 'FilteringAndDerivatives', 'filter', ...
          'SimscapeFilterOrder', '1', 'InputFilterTimeConstant', 'G_tau');
end

function conn(sys, a, b)
% Connect two physical ports.
add_line(sys, a, b, 'autorouting', 'smart');
end
