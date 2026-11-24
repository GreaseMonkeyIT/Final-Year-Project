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
%   The _grp models give each group its own irradiance. G is then a
%   12 x 4 matrix (scripts/add_pv_array.m, shading_patterns_grp.m).

%% Panel: Emmvee E325P72
% Datasheet (Literature/Emmvee_PV_Module_Brochure_E325P72_p4.pdf, page 4),
% at 1000 W/m^2, 25 degC, AM 1.5:
%   Pmax 325 W, Voc 45.8 V, Isc 9.11 A, Vmp 37.4 V, Imp 8.68 A,
%   72 multicrystalline cells, 3 bypass diodes.
%   Temperature coefficients: Voc -0.34 %/K, Isc +0.05 %/K, Pmax -0.40 %/K.
%   NOCT 46 degC. Since 2026-11-21 the models use these values: see
%   "Temperature" below.
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
% Temperature (added 2026-11-21, docs/notes/final_test_plan.md, step 0.1).
% The Solar Cell block changes Iph, Is and Rs with the cell temperature
% (equations in src/plant/pv_array_curve.m). TIPH1 is the Isc coefficient
% of the datasheet. EG is the block default for silicon. TXIS1 is fitted
% so that the array Voc changes by -0.34 %/K from 25 degC to 65 degC
% (build/fit_temperature.m). With these values the model gives
% Voc -0.340 %/K, Isc +0.050 %/K and Pmax -0.420 %/K (datasheet -0.40 %/K,
% 5 % off). TRS1 = 0: a larger value moves Pmax further from the datasheet.
m.Tmeas    = 25;      % Temperature of the datasheet values [degC]
m.TIPH1    = 5e-4;    % First-order temperature coefficient of Iph [1/K] (Isc +0.05 %/K)
m.EG       = 1.11;    % Energy gap [eV]
m.TXIS1    = 6.41;    % Temperature exponent of Is (fitted to the Voc coefficient)
m.TRS1     = 0;       % Temperature exponent of Rs
m.cVoc_ds  = -0.34;   % Datasheet coefficients [%/K], for checks only
m.cIsc_ds  = 0.05;
m.cPmp_ds  = -0.40;
m.NOCT     = 46;      % Nominal operating cell temperature [degC]
cfg.mod = m;
cfg.Tcell = 25;       % Cell temperature of the models [degC], the same for all the cells.
                      % The run scripts set the model variable pv_T for each run.

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

%% Sensors and ADC (added 2026-11-21, docs/notes/final_test_plan.md, step 0.2)
% The block "Sensors and ADC" of MPPT_4x4.slx is between the plant and the
% controller (src/plant/sensor_adc.m). With sens.on = 0 the controller
% gets the exact values, as before 2026-11-21. The parts are typical
% parts. The report marks them as assumptions:
%   Voltage: resistive divider and isolation amplifier AMC1311 (TI,
%   SBAS786, AMC1311 grade): input range 0 V to 2 V, gain 1, then a
%   differential-to-single-ended stage with gain 1.5 to the ADC range.
%   Current: closed-loop Hall transducer LEM LA 55-P (datasheet version
%   17, 2018), 1:1000, measuring resistor RM, unidirectional.
%   ADC: TMS320F28379D (TI, SPRS880P), 12-bit single-ended mode,
%   VREFHI = 3.0 V, one conversion each control sample Tc.
% Static errors use the typical values of the datasheets. A run script can
% give each run its own errors (random sign and size up to these values).
s.on      = 0;         % 1 = sensors and ADC, 0 = exact measurement
s.bits    = 12;        % ADC resolution
s.FS      = 3.0;       % ADC range, VREFHI - VREFLO [V]
s.kV      = 3.0 / 200; % Volts at the ADC pin per volt of Vpv: 200 V full scale
                       % (array Voc 183.2 V at 25 degC, about 189 V at 15 degC)
s.kI      = 0.056;     % Volts at the ADC pin per ampere: RM = 56 Ohm and 1:1000,
                       % 53.6 A full scale (array Isc 36.4 A, 47 A at 1300 W/m^2).
                       % LA 55-P with +/-15 V: RM from 50 Ohm to 160 Ohm at 50 A.
s.eV      = 0.004;     % Gain error of the voltage path: AMC1311 0.4 % typical
                       % (max 1 %). Divider resistors of 0.1 % add up to 0.2 %.
s.oV      = 0.4e-3 * 1.5;  % Offset of the voltage path at the ADC pin [V]: AMC1311
                       % 0.4 mV typical (max 9.9 mV), times the gain 1.5
s.nV      = 220e-6 * 1.5;  % Noise of the voltage path at the ADC pin, rms [V]: AMC1311
                       % output noise 220 uV rms (BW 100 kHz), times 1.5
s.eI      = 0.0065;    % Gain error of the current path: LA 55-P 0.65 % at IPN (+/-15 V)
s.oI      = 0.2e-3 * 56;   % Offset of the current path at the ADC pin [V]: 0.2 mA
                       % secondary offset times RM
s.nI      = 0;         % Noise of the current path [V rms]: not given in the LA 55-P
                       % datasheet, so only the ADC noise applies
s.adc_gain = 3;        % ADC gain error [LSB], typical (max 5)
s.adc_off  = 2;        % ADC offset error [LSB], typical (max 4)
s.adc_inl  = 1;        % ADC INL [LSB], typical (max 2): a bow over the range
s.adc_n    = 0.42;     % ADC input noise, rms [LSB]. SNR 69.1 dB at full scale gives
                       % 0.508 LSB rms of total noise. Quantization gives 0.289 LSB,
                       % so the other noise is sqrt(0.508^2 - 0.289^2) = 0.42 LSB.
s.seed    = 1;         % Seed of the noise generators
cfg.sens = s;

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
p.alg    = 1;          % 1 = P&O, 2 = INC, 9 = replay. Global search, then the local stage:
                       % 3 = DIRECT (Nguyen and Low 2010), 4 = Idea B refined,
                       % 5 = Idea C, 6 = PSO (Ishaque et al. 2012), 7 = GWO (Mohanty
                       % et al. 2016), 8 = not used (gmppt_search.m).
                       % The run scripts set this for each run.
p.Tc     = 50e-6;      % Control sample time [s], one 20 kHz switching period
p.Tmppt  = 20e-3;      % MPPT period [s]
p.Nper   = round(p.Tmppt / p.Tc);   % Control samples in one MPPT period
p.Navg   = round(p.Nper / 2);       % Samples averaged: the second half of the period
% Search probes of a global search use a longer period. A large duty
% jump into the low-voltage part of the curve starts a ringing of L and
% C_in at about 670 Hz that decays with a time constant of about 6 ms.
% There, the array acts as a current source and adds almost no damping. With
% 20 ms and the second half, a probe can be 4.4 % off its settled power.
% With 40 ms and the last quarter, the worst error is 0.21 %
% (experiments/templates/run_settling_check.m, docs/notes/pv4x4_shading_and_po.md, section 5).
p.Tsearch = 40e-3;                    % Period of one search probe [s]
p.Nper_s  = round(p.Tsearch / p.Tc);  % Control samples in one search probe
p.Navg_s  = round(p.Nper_s / 4);      % Samples averaged: the last quarter of the probe
p.dD     = 0.005;      % Duty step
p.Dstart = 0.30;       % Duty at start-up. R_in = 54 Ohm, so the array is near Voc,
                       % to the right of the highest-voltage peak of every pattern
                       % (the highest of these is 31 Ohm, for R1).
p.Dmin   = 0.05;
p.Dmax   = 0.95;
p.Nwait  = 3;          % MPPT periods at Dstart before tracking starts
p.eps_inc = 0.30;      % INC holds when |dI/dV + I/V| <= eps_inc * I/V, which is the same as
                       % |dP/dV| <= eps_inc * I. On this array, 0.30 is 2.0 V to 2.7 V on
                       % each side of a smooth peak (0.6 V on the sharp peak of R1), less
                       % than one duty step (about 4 V). At the edge of the band the loss
                       % is up to 0.33 % (corrected 2026-11-21, docs/notes/
                       % gmppt_local_stage_2026-11-21.md, section 2.1; the old comment
                       % said +/-1.5 V). A narrow band
                       % (0.05) almost never holds, because one step jumps over it.
p.eps_di  = 0.005;     % After a hold, INC moves only if |dI| > eps_di * I. dI is the change
                       % since the first period of the hold (since 2026-11-22; before, the
                       % change since the last period, which a slow ramp never exceeded).
% Global search (p.alg = 3 to 8), see gmppt_search.m and docs/notes/gmppt_methods.md.
% Each search probe lasts p.Tsearch. After the search, the local stage
% that p.local selects starts from the hand-over duty.
p.Dlo     = 0.30;      % Duty range of the search. 0.30 puts the array near Voc,
p.Dhi     = 0.78;      % 0.78 near 0.15 Voc. Same range as the preliminary study.
% Restart of the global search during the local stage (mppt_controller.m).
% Power-change trigger. The test is the relative power change, the most
% common form in the literature: Liu et al., IEEE Trans. Energy Convers.
% 27(4), 2012, Eq. (8). Wang, Li and Ruan, IEEE Trans. Ind. Electron.
% 63(1), 2016, Eq. (7). Kermadi et al., IEEE Trans. Ind. Electron. 66(9),
% 2019. Li et al., IEEE Access 7, 2019, Eq. (3). The controller makes the
% test only between two periods with the same duty, so a step of the
% local stage cannot start a search. Nguyen and Low (2010, section IV-B)
% describe the same condition: the power changes while the duty does not.
p.dP_restart = 0.05;   % Search again if |P - P_ref| > dP_restart * P_ref (0 = off).
                       % 0.05 is the value of the preliminary study. Published
                       % values: 0.015 (Ishaque et al. 2012), 0.02 (Li et al. 2019),
                       % 0.05 of the rated power (Furtado et al., IEEE Trans. Ind.
                       % Electron. 65(4), 2018), 0.1 (Wang et al. 2016, Kermadi et al. 2019).
p.restart_ref = 2;     % Reference power P_ref of the trigger:
                       % 1 = the power of the latest earlier period with the same
                       %     duty (one to four periods before). This tests a rate
                       %     of change: a change slower than dP_restart in 20 ms
                       %     to 80 ms never starts a search.
                       % 2 = the power of the first settled period after the
                       %     hand-over (the stored power of the tracked peak, as
                       %     in Wang et al. 2016 and Li et al. 2019). This tests
                       %     the size of the change, however slow it is.
                       % Changed from 1 to 2 on 2026-11-22 with the approval of the
                       % user: with 1, a slow cloud edge (phase 3, event 40) started
                       % no search, and the power stayed near 72 % of the GMPP.
% Power floor of the level test (added on 2026-11-24 with the approval of the
% user, docs/notes/gmppt_methods.md, section 8.1). A choice of this project.
% On full days, most searches started at dawn and at dusk: the light rises
% slowly enough to pass the steady test, so each 5 % rise started a search.
% Below the floor, the level test is off. It is on again when the power is
% above P_floor_hys * P_floor. P_ref does not change below the floor. The
% absolute threshold of Furtado et al. 2018 (5 % of the rated power) has the
% same effect at low power: below that power, no change can reach it.
p.P_floor     = 260;   % [W], 5 % of the rated power of the array (16 x 325 W). 0 = off.
                       % Static bench, 4 full days, Idea C: 99.968 % with 521 searches
                       % (no floor: 99.779 % with 8413). 2 %: 99.897 %. 10 %: no gain
                       % in the needed steps, fewer searches.
p.P_floor_hys = 1.1;   % The level test is on again above P_floor_hys * P_floor
                       % (a band against flicker near the floor).
% Fixed periodic rescan, whatever the power does (Xu et al., IEEE Trans.
% Ind. Electron. 68(1), 2021, give the reason: a change on bypassed panels
% can leave the power at the held point the same).
p.T_rescan   = 900;    % Search again after T_rescan seconds of the local stage [s]
                       % (0 = off). 900 s = 15 min: Koutroulis and Blaabjerg, IEEE J.
                       % Photovolt. 2(2), 2012, report a loss below 0.06 % for a scan
                       % each 15 min on an array with no shade. Wang et al. 2016 use
                       % 15 min. The SMA ShadeFix manual gives 6 min as the usual
                       % value (range 180 s to 3600 s). A simulation run lasts only
                       % a few seconds, so the run script must set its own value.
% Replay (p.alg = 9). The controller applies each entry of Drep for Nhold
% periods, from period Nwait + 1, and then holds the last entry. There is
% no tracking. experiments/templates/run_settling_check.m uses this to apply the duty sequence
% of a search.
p.Nmax   = 64;               % Size of the fixed arrays of the controller
p.Drep   = zeros(1, p.Nmax); % Duty list of the replay
p.Nrep   = 0;                % Number of entries in Drep that are used
p.Nhold  = 1;                % MPPT periods for each entry of Drep

%% Local stage after a global search (p.alg = 3 to 8)
p.local  = [3 3 3 3 3 3 3 3];   % Local stage for each p.alg (entry p.alg is used;
                       % entries 1, 2 and 8 are not used). A run script can also give
                       % one value for all the searches.
                       % Changed on 2026-11-21 with the approval of the user, from 2 for
                       % all searches to 3 for DIRECT, Idea B and Idea C (p.alg = 3, 4,
                       % 5). Reason: on an irradiance ramp the variable-step INC does not
                       % move after its hold (docs/notes/gmppt_local_stage_2026-11-21.md,
                       % section 6.3). Changed again on 2026-11-21 (evening), from
                       % [2 2 3 3 3 2 2 2] to 3 for all searches, PSO and GWO included:
                       % the final tests compare the searches with the same local stage
                       % (docs/notes/final_test_plan.md, section 1).
                       % Values:
                       % 1 = fixed-step P&O with the step p.dD (as p.alg = 1).
                       % 2 = variable-step INC of Liu et al., IEEE Trans. Ind.
                       %     Electron. 55(7), 2008 (mppt_controller.m).
                       % 3 = parabolic stage (Pai et al. 2011, Brent 1973, Sera et
                       %     al. 2008). Values p.par_* and p.chk_*.
                       % 4 = INC of p.alg = 2 (the INC of the mid-review) with the
                       %     step p.dD and the bands p.eps_inc and p.eps_di.
p.paper_end = 0;       % 0 = each search hands over to the stage of p.local.
                       % 1 = each search ends as its paper says: DIRECT with a P&O
                       %     of step p.dir_dcr, PSO and GWO with a fixed duty.
                       %     Ideas B and C have no ending of their own.
% Variable-step INC: duty step = p.vs_N * |dP/dV|, Liu et al. 2008, Eq. (4).
p.vs_dDmax = 0.02;     % Largest duty step (the upper limiter of the paper). The paper
                       % gives no rule for it. 0.02 is 4 times p.dD. The paper uses
                       % 5 times its small fixed step (0.05 against 0.01).
p.vs_N     = 4e-4;     % Scaling factor N [1/(W/V)]. Method of the paper, Eq. (6):
                       % N < dDmax / |dP/dV|, with |dP/dV| measured one step dDmax
                       % from the peak. On the static curves of results/pv4x4_sweeps.mat
                       % with dDmax = 0.02: uniform array (P0) 27.5 W/V, so N < 7.3e-4.
                       % The lowest limit of the nine patterns is 4.95e-4 (R1).
                       % 4e-4 is below all nine limits. Calculated, not yet run in Simulink.
p.vs_dDmin = 0.001;    % Smallest duty step. The paper has no lower limit. This value
                       % is the step of the first perturbation and of the move after a hold.
p.vs_hold_dir = 1;     % Direction of the move after a hold, when the current changed
                       % by more than p.eps_di * I:
                       %  1 = as the flowchart of Liu et al. (Fig. 2): more current,
                       %      duty up. On a resistive load, more light moves the
                       %      peak to a lower input resistance, which is a higher duty.
                       % -1 = more current, duty down (the INC of p.alg = 2 used this
                       %      direction until 2026-11-22; it now uses duty up).
% The hold band p.eps_inc and the current band p.eps_di of the INC of
% p.alg = 2 also apply to the variable-step INC.
% Parabolic stage (p.local = 3), added 2026-11-21 with the approval of the
% user. mppt_controller.m and docs/notes/gmppt_local_stage_2026-11-21.md,
% section 5, describe it. The values below are start values from the
% static analysis, not tuned.
p.par_kmax = 3;        % Most probes of the refinement (40 ms each)
p.par_tol  = 0.001;    % tol of Brent (duty): no probe nearer than this to a known point.
                       % The same as p.vs_dDmin.
p.par_h    = 0.01;     % Distance of the end probe if the best sample has no neighbour
                       % on one side (duty). The same as p.tau.
p.chk_eps  = 0.01;     % The fresh reading differs from the stored best power by more
                       % than this fraction: the stored samples are old. 1 %, larger
                       % than the settling error of a probe (0.21 %).
p.chk_T    = 1;        % Time of hold between two checks [s]
p.chk_d    = 0.002;    % Duty step of the check. Near a peak it changes the power by
                       % 0.01 % to 0.2 %, so the check sees it.
p.chk_db   = 1e-4;     % Dead band: the check moves the duty only if the predicted gain
                       % is more than this fraction of the power. Much smaller than
                       % p.dP_restart, as Andrean et al. (Energies 11, 2018, section
                       % 3.3) require for the end test and the change test.
p.chk_ramp = 1e-3;     % The centre power changed by more than this fraction during a
                       % check: the irradiance drifts, and the next check follows at once
                       % (only with p.vh_on = 0; with the voltage hold, the hold follows
                       % the drift)
% Restart rule and voltage hold (added on 2026-11-22 with the approval of the
% user, docs/notes/gmppt_methods.md, section 8). The parts come from
% published rules: the level test of Wang et al. 2016, Furtado et al. 2018,
% Li et al. 2019 and Ahmed et al. 2023; the steady-state condition of
% Boztepe et al. 2014; the voltage hold of the two-loop structure of
% Boztepe et al. 2014, Furtado et al. 2018 and Kermadi et al. 2019.
p.st_band  = 2e-4;     % Steady state: the power changes by at most this fraction per
                       % period of 20 ms (1 % per second)
p.st_win   = 10;       % Periods of the steady test (0.2 s, at most 32). The rate of change
                       % is the slope of a least-squares line through the last st_win
                       % powers (parabolic hold), or the mean of the last st_win matched
                       % rates (local stages 1, 2, 4). Since 2026-11-23, with the approval
                       % of the user. Before: st_N = 5 periods in a row, each with a change
                       % of at most st_band. Sensor noise broke that test (phase p3n):
                       % at 1 x noise at 100 W/m2 it passed in 27 % of the 0.1 s windows,
                       % at 10 x noise in full sun in 11 %. The fit over 10 periods
                       % passed in 91 % to 100 % of the windows up to 10 x noise.
p.vh_on    = 1;        % Parabolic stage: 1 = hold the voltage between checks, 0 = hold
                       % the duty (as before 2026-11-22)
p.vh_k     = 1;        % Gain of the voltage hold. 1 = the step of the ideal buck-boost
                       % that brings V to V0 at a constant current. Near the peak the
                       % current also changes, so this step is smaller than the full step
                       % and does not overshoot.
p.vh_max   = 0.01;     % Largest duty move of the voltage hold in one period

%% DIRECT of Nguyen and Low, IEEE Trans. Ind. Electron. 57(10), 2010 (p.alg = 3, 4)
p.dir_range = 0;       % Sampling interval: 0 = p.Dlo to p.Dhi. 1 = p.dir_Dlo_abs to
                       % p.dir_Dhi_abs, the absolute sampling interval of the paper.
% Absolute sampling interval, Eqs. (13) to (18) of the paper. The paper
% gives none of its input values. It reports only its result for its own
% plant, (0.45, 0.85). The eight values below are values of this project.
p.dir_Voc_max = a.Voc;          % Highest open-circuit voltage [V]: the array at 25 degC
p.dir_Voc_min = a.Voc;          % Lowest open-circuit voltage [V]. Not changed when the cell temperature was added (2026-11-21): the absolute interval is off (p.dir_range = 0)
p.dir_Isc_max = a.Isc;          % Highest short-circuit current [A]: 1000 W/m^2
p.dir_Isc_min = 0.15 * a.Isc;   % Lowest short-circuit current [A]: 150 W/m^2, diffuse light
p.dir_alpha   = 0.15;           % Scaling factor of Voc_min in Eq. (13), below 1
p.dir_beta    = 0.7;            % Scaling factor of Isc_min in Eq. (14), below 1
p.dir_eta     = 1.0;            % Converter efficiency in Eq. (15). The averaged model is near 1
p.dir_Rload_min = c.Rload;      % Lowest and highest load resistance [Ohm]. The load is fixed
p.dir_Rload_max = c.Rload;
Rpv_min = p.dir_alpha * p.dir_Voc_min / p.dir_Isc_max;            % Eq. (13): 0.754 Ohm
Rpv_max = p.dir_Voc_max / (p.dir_beta * p.dir_Isc_min);           % Eq. (14): 47.9 Ohm
p.dir_Dlo_abs = sqrt(p.dir_eta * p.dir_Rload_min) / ...
    (sqrt(Rpv_max) + sqrt(p.dir_eta * p.dir_Rload_min));          % Eq. (17): 0.314
p.dir_Dhi_abs = sqrt(p.dir_eta * p.dir_Rload_max) / ...
    (sqrt(Rpv_min) + sqrt(p.dir_eta * p.dir_Rload_max));          % Eq. (18): 0.785
p.dir_c19   = 0.1;     % Shading test on the current, Eq. (19) of the paper
p.dir_c20   = 0.2;     % Shading test on the voltage, Eq. (20) of the paper
p.dir_eps_g = 0.03;    % epsilon of Eq. (12) in the globally biased stage (section III-B
                       % of the paper: the largest error of the measured power)
p.dir_eps_l = 0;       % epsilon in the locally biased stage (section III-B). The local
                       % stage always divides the best interval, so the code does not
                       % read this value. It is here for the record.
p.dir_Voc   = a.Voc;   % Voc of the skip rules [V]. The paper does not say which Voc.
p.dir_Isc   = a.Isc;   % Isc of the skip rules [A]. This project uses the rated values
                       % of the array at STC (docs/notes/gmppt_methods.md, section 2.4).
p.dir_kVmin = 1/3;     % Skip rule 1: Vmin = Voc / 3 (section IV-C of the paper)
p.dir_kImin = 1/3;     % Skip rule 2: Imin = Isc / 3
p.dir_kVmax = 0.9;     % Skip rule 2: Vmax = 0.9 Voc
p.dir_dcr   = 0.0025;  % Critical duty change of Eq. (21). The paper gives no value. It
                       % says only that dcr is smaller than the P&O step. 0.0025 is half
                       % of p.dD. On a range of 0.48, each value from 0.0020 to 0.0059
                       % ends the search at the same level (5 divisions). With
                       % p.paper_end = 1, dcr is also the step of the P&O after DIRECT.

%% Ceiling check of Ideas B and C (p.alg = 4, 5), gmppt_ceiling.m
p.eps_c    = 0.02;     % A gap is open if its ceiling is above (1 + eps_c) * P_best
p.tau      = 0.01;     % A gap is open only if it is wider than tau (duty)
p.delta_s  = 0;        % Bound of the relative sensor error (0 = exact sensors)
p.theta    = 0.1;      % Corner split: the split stays theta * width from each end
p.c_corner = 1;        % Idea C: 0 = split at the midpoint, 1 = split at the corner duty.
                       % Changed from 0 to 1 on 2026-11-21 with the approval of the user.
                       % Static check on the nine patterns: 93 probes in place of 118, and
                       % a mean hand-over power of 99.91 % in place of 99.85 % of the GMPP
                       % (docs/notes/gmppt_local_stage_2026-11-21.md, section 2).
% Margins of Idea B (added 2026-11-21 with the approval of the user, open
% question 8.3, item 5, of docs/notes/gmppt_review.md). The DIRECT samples
% do not reach the ends of the range. With p.mg_on = 1, the ceiling check
% also bounds the two margins and samples an end only if its margin is open:
%   p.Dlo to the lowest sample:  U = p.mg_Voc * I(lowest sample)
%   highest sample to p.Dhi:     U = V(highest sample) * p.mg_Isc
p.mg_on  = 1;          % Idea B: 1 = margins are gaps, 0 = no margins (as delivered)
p.mg_Voc = a.Voc;      % Upper limit of the array Voc [V]: the array at 25 degC. The final tests run up to 65 degC, where Voc is lower, so the bound holds. Below 25 degC it is too low by 0.34 %/K.
                       % For a real array, use the Voc at the lowest cell temperature.
p.mg_Isc = a.Isc;      % Upper limit of the array Isc [A]: 1000 W/m^2 in all the
                       % patterns. For a real array, add a margin for cloud enhancement.

%% PSO of Ishaque et al., IEEE Trans. Power Electron. 27(8), 2012 (p.alg = 6)
p.pso_w   = 0.4;       % Inertia weight (section V of the paper)
p.pso_c1  = 1.2;       % Acceleration coefficient of Pbest (section V)
p.pso_c2  = 1.6;       % Acceleration coefficient of Gbest (section V)
p.pso_D0  = p.Dlo + (p.Dhi - p.Dlo) * ((1:8) - 0.5) / 8;   % Start duties of the particles.
                       % The number of entries is the number of particles. The paper uses
                       % 3 (Fig. 8) and does not give the first duties. These are the
                       % centers of equal parts of the range.
                       % Changed from 3 to 8 particles on 2026-11-21 with the approval of
                       % the user. Static check, 50 seeds x 9 patterns: 3 particles hand
                       % over on a wrong peak in 10.7 % of the runs, 8 particles in 0 %
                       % (docs/notes/gmppt_local_stage_2026-11-21.md, section 3). For the
                       % setting of the paper: [1/6, 1/2, 5/6] and p.pso_itmax = 20.
p.pso_dpert = 0.005;   % Small perturbation of the Gbest particle (section IV-B). The
                       % paper gives no value. This is one P&O step, p.dD.
p.pso_tol   = 0.005;   % End test, not in the paper: each particle has |velocity| <= tol
                       % and is not more than tol from Gbest (duty)
p.pso_itmax = 8;       % Most iterations of one search, not in the paper. 8 x 8 probes
                       % fit in the store of p.Nmax = 64 samples. Changed from 20 to 8
                       % on 2026-11-21, with the change to 8 particles.
p.pso_reinit = 0;      % Start of a restart: 0 = p.pso_D0. 1 = Eqs. (16), (17) and (19)
                       % of the paper, around the last duty.
p.pso_K1    = 1.7e4;   % K1 of Eq. (16) [W per unit of duty] for a fall of the power. A
                       % rise uses K1 / 2 (Eq. (17)). Method of the paper (Fig. 7): the
                       % slope of the peak power against the best duty. Estimate for
                       % this array with the ideal converter, from 100 W/m^2 (519 W at
                       % D = 0.32) to 1000 W/m^2 (5194 W at D = 0.60). UNVERIFIED: not
                       % fitted on simulated points.
p.pso_K2    = 0.05;    % Displacement of the two outer particles, Eq. (19)

%% GWO of Mohanty et al., IEEE Trans. Sustain. Energy 7(1), 2016 (p.alg = 7)
% The paper gives only "a decreases linearly from 2 to 0". The three
% values below are not in the paper.
p.gwo_D0    = p.Dlo + (p.Dhi - p.Dlo) * ((1:6) - 0.5) / 6;   % Start duties of the wolves:
                       % the centers of equal parts of the range. The number of entries is
                       % the number of wolves, at least 3. The paper gives no number.
                       % Changed from 3 to 6 wolves on 2026-11-21 with the approval of the
                       % user. Static check, 50 seeds x 9 patterns: 3 wolves hand over on a
                       % wrong peak in 5.6 % of the runs, 6 wolves in 0 %
                       % (docs/notes/gmppt_local_stage_2026-11-21.md, section 3). The old
                       % value, [1/6, 1/2, 5/6], came from a secondary report of a later
                       % paper of the same authors (IEEE Trans. Energy Convers. 32(1),
                       % 2017), which is not in docs/references/.
p.gwo_itmax = 10;      % Iterations in which a goes from 2 to 0. Value of this project:
                       % 10 x 6 probes = 2.4 s of search.
p.gwo_tol   = 0.005;   % End test, value of this project: each wolf is not more than
                       % tol from the alpha wolf (duty)

%% State reset (added 2026-11-21)
% p.reset = 1 makes mppt_controller.m start again from its first state at
% that call. Only the static test bench (src/plant/static_run.m) sets it,
% on the first call of each run, so that the MEX file needs no reload.
% The Simulink models always use 0.
p.reset = 0;

%% Random numbers of PSO and GWO (gmppt_rand.m)
p.rng_seed  = 12345;   % Start value of the generator, an integer from 1 to 2^31 - 2
cfg.mppt = p;
end
