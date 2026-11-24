function cfg = pv4x4_config()
%PV4X4_CONFIG Values for the 4 x 4 PV array models and the MPPT runs.
%
%   cfg = pv4x4_config() returns one struct with all the values that
%   scripts/build_pv4x4_sweep.m, scripts/build_mppt_4x4.m, and the run
%   scripts use.
%   Change a value here, then run the build script again.
%
%   The build scripts copy the panel and diode values into the model
%   workspace as pv_* and byp_* variables. You can also change them there
%   (Model Explorer > Model Workspace). All 16 panels use the same
%   variables, so one change updates the full array.
%
%   Array layout. G is a 4 x 4 irradiance matrix in W/m^2. Row 1 is the
%   top row. Each COLUMN of G is one string: four panels in series, top
%   to bottom. The four strings are in parallel (series-parallel, SP).
%   Each panel has Nbyp groups of cells in series, with one bypass diode
%   across each group. All the groups of a panel get the same irradiance.

%% Panel: Emmvee E325P72
% Datasheet (Literature/Emmvee_PV_Module_Brochure_E325P72_p4.pdf, page 4),
% at 1000 W/m^2, 25 degC, AM 1.5:
%   Pmax 325 W, Voc 45.8 V, Isc 9.11 A, Vmp 37.4 V, Imp 8.68 A,
%   72 multicrystalline cells, 3 bypass diodes.
%   Temperature coefficients: Voc -0.34 %/K, Isc +0.05 %/K, Pmax -0.40 %/K.
%   NOCT 46 degC. The models run at 25 degC and do not use these values.
% The Solar Cell block of Simscape Electrical is parameterized by the
% short-circuit current and the open-circuit voltage of one cell. The two
% free values, n and Rs, are fitted to the datasheet:
%   n = 1.0 and Rs = 4.41 mOhm per cell (0.318 Ohm per panel) give
%   Pmax 324.6 W at 37.53 V and 8.65 A (Vmp +0.35 %, Imp -0.35 %).
%   An exact fit of Vmp and Imp needs n = 0.91, which is not physical for
%   a silicon cell.
% For a different panel: set Ncell, Nbyp, Isc_cell = Isc, and
% Voc_cell = Voc/Ncell. Then fit Rs_cell until the model Pmax matches the
% datasheet Pmax.
m.name     = 'Emmvee E325P72 (72-cell multicrystalline, 3 bypass diodes)';
m.Ncell    = 72;      % Cells in series in one panel
m.Nbyp     = 3;       % Bypass diodes in one panel (Ncell/Nbyp = 24 cells in each group)
m.Isc_cell = 9.11;    % Short-circuit current at 1000 W/m^2 [A]
m.Voc_cell = 45.8 / 72;   % Open-circuit voltage of one cell [V]
m.n        = 1.0;     % Diode ideality factor (fitted)
m.Rs_cell  = 4.41e-3; % Series resistance of one cell [Ohm] (fitted)
m.Ir0      = 1000;    % Irradiance of the Isc and Voc values [W/m^2]
m.Voc      = m.Ncell * m.Voc_cell;   % 45.8 V
m.Isc      = m.Isc_cell;             % 9.11 A
m.Pmp_ds   = 325;     % Datasheet values, for checks only
m.Vmp_ds   = 37.4;
m.Imp_ds   = 8.68;
cfg.mod = m;

%% Array
a.Nser = 4;                    % Panels in series in one string (rows of G)
a.Npar = 4;                    % Strings in parallel (columns of G)
a.Voc  = a.Nser * m.Voc;       % 183.2 V
a.Isc  = a.Npar * m.Isc;       % 36.44 A
cfg.arr = a;

%% Bypass diode: 15SQ045 Schottky (values from set_realistic_diodes.m)
% Rating 45 V, 15 A. One diode covers 24 cells (Voc 15.3 V), and the
% panel Isc is 9.11 A, so both are in range.
cfg.byp.Vf   = 0.37;     % [V]
cfg.byp.Ron  = 0.012;    % [Ohm]
cfg.byp.Goff = 4.4e-6;   % [S]

%% Irradiance input
% The Simulink-PS converters of the irradiance inputs use a first-order
% filter. A step in G then becomes a 1 ms ramp, which the solver handles
% without a reset.
cfg.G_tau = 1e-3;        % [s]

%% Sweep testbench (PV4x4_sweep.slx)
cfg.sweep.Tstop = 1;             % [s]
cfg.sweep.Vend  = a.Voc;         % End of the voltage ramp [V]. Stop at Voc (see Notes, section 3).
cfg.sweep.Tlog  = 2.5e-4;        % Log sample time [s], 4000 points

%% Converter and load (Average-Value DC-DC Converter, buck-boost)
% L, Cout, and Cin are the values of MPPT_avg.slx. The averaged model has
% no ripple, so these values set only the dynamics. The load is 10 Ohm.
% R_in = Rload*((1-D)/D)^2. The array MPP (4.3 Ohm, 150 V, 34.7 A) is
% near D = 0.60, and the output is then about 230 V.
c.L        = 150e-6;   % [H]
c.RL       = 10e-3;    % [Ohm]
c.Cout     = 470e-6;   % [F]
c.Rc       = 50e-3;    % ESR of Cout [Ohm]
c.Cin      = 220e-6;   % PV-side capacitor [F]
c.Cin_esr  = 50e-3;    % ESR of Cin [Ohm], typical for a 250 V electrolytic
c.Rload    = 10;       % [Ohm]
cfg.conv = c;

%% MPPT on the duty cycle (P&O and INC)
% The controller runs once per control sample Tc, as it would in an ADC
% interrupt on the real-time target. It averages V and I over the last
% part of each MPPT period, then makes one decision. One period is one
% applied operating point. See mppt_controller.m.
p.alg    = 1;          % 1 = P&O, 2 = INC. run_po_demo.m sets this for each run.
p.Tc     = 50e-6;      % Control sample time [s], one 20 kHz switching period
p.Tmppt  = 20e-3;      % MPPT period [s]
p.Nper   = round(p.Tmppt / p.Tc);   % Control samples in one MPPT period
p.Navg   = round(p.Nper / 2);       % Samples averaged: the second half of the period
p.dD     = 0.005;      % Duty step
p.Dstart = 0.30;       % Duty at start-up. R_in = 54 Ohm, so the array is near Voc,
                       % to the right of the highest-voltage peak of every pattern
                       % (the highest of these is 31 Ohm, for R1).
p.Dmin   = 0.05;
p.Dmax   = 0.95;
p.Nwait  = 3;          % MPPT periods at Dstart before tracking starts
p.eps_inc = 0.30;      % INC holds when |dI/dV + I/V| <= eps_inc * I/V, which is the same as
                       % |dP/dV| <= eps_inc * I. On this array, 0.30 is about +/-1.5 V around
                       % a smooth peak, less than one duty step (about 4 V). A narrow band
                       % (0.05) almost never holds, because one step jumps over it.
p.eps_di  = 0.005;     % After a hold, INC moves only if |dI| > eps_di * I
cfg.mppt = p;
end
