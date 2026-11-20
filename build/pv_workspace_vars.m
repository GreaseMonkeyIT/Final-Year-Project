function pv_workspace_vars(mdl, cfg)
%PV_WORKSPACE_VARS Put the panel and diode values into the model workspace.
%
%   pv_workspace_vars(mdl, cfg) writes the pv_*, byp_*, and G_tau
%   variables that the blocks of add_pv_array read. cfg comes from
%   pv4x4_config. The Solar Cell block needs the values for one cell.
%   pv_Ngrp is the number of cells in one bypass-diode group, which is
%   the number of cells in one Solar Cell block. pv_Ncell (cells in one
%   panel) is for information only.

m  = cfg.mod;
ws = get_param(mdl, 'ModelWorkspace');
assignin(ws, 'pv_Ncell', m.Ncell);
assignin(ws, 'pv_Ngrp',  m.Ncell / m.Nbyp);
assignin(ws, 'pv_Isc',   m.Isc_cell);
assignin(ws, 'pv_Voc',   m.Voc_cell);
assignin(ws, 'pv_n',     m.n);
assignin(ws, 'pv_Rs',    m.Rs_cell);
assignin(ws, 'pv_Ir0',   m.Ir0);
assignin(ws, 'byp_Vf',   cfg.byp.Vf);
assignin(ws, 'byp_Ron',  cfg.byp.Ron);
assignin(ws, 'byp_Goff', cfg.byp.Goff);
assignin(ws, 'G_tau',    cfg.G_tau);
end
