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
                       % |dP/dV| <= eps_inc * I. On this array, 0.30 is about +/-1.5 V around
                       % a smooth peak, less than one duty step (about 4 V). A narrow band
                       % (0.05) almost never holds, because one step jumps over it.
p.eps_di  = 0.005;     % After a hold, INC moves only if |dI| > eps_di * I
% Global search (p.alg = 3 to 8), see gmppt_search.m and docs/methods.md.
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
p.restart_ref = 1;     % Reference power P_ref of the trigger:
                       % 1 = the power of the latest earlier period with the same
                       %     duty (one to four periods before).
                       % 2 = the power of the first settled period after the
                       %     hand-over (the stored power of the tracked peak, as
                       %     in Wang et al. 2016 and Li et al. 2019).
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
p.local  = 2;          % 1 = fixed-step P&O with the step p.dD (as p.alg = 1).
                       % 2 = variable-step INC of Liu et al., IEEE Trans. Ind.
                       %     Electron. 55(7), 2008 (mppt_controller.m).
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
                       % -1 = as the INC of p.alg = 2: more current, duty down.
% The hold band p.eps_inc and the current band p.eps_di of the INC of
% p.alg = 2 also apply to the variable-step INC.

%% DIRECT of Nguyen and Low, IEEE Trans. Ind. Electron. 57(10), 2010 (p.alg = 3, 4)
p.dir_range = 0;       % Sampling interval: 0 = p.Dlo to p.Dhi. 1 = p.dir_Dlo_abs to
                       % p.dir_Dhi_abs, the absolute sampling interval of the paper.
% Absolute sampling interval, Eqs. (13) to (18) of the paper. The paper
% gives none of its input values. It reports only its result for its own
% plant, (0.45, 0.85). The eight values below are values of this project.
p.dir_Voc_max = a.Voc;          % Highest open-circuit voltage [V]: the array at 25 degC
p.dir_Voc_min = a.Voc;          % Lowest open-circuit voltage [V]. The models run at 25 degC only
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
                       % of the array at STC (docs/methods.md, section 2.4).
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
p.c_corner = 0;        % Idea C: 0 = split at the midpoint, 1 = split at the corner duty

%% PSO of Ishaque et al., IEEE Trans. Power Electron. 27(8), 2012 (p.alg = 6)
p.pso_w   = 0.4;       % Inertia weight (section V of the paper)
p.pso_c1  = 1.2;       % Acceleration coefficient of Pbest (section V)
p.pso_c2  = 1.6;       % Acceleration coefficient of Gbest (section V)
p.pso_D0  = p.Dlo + (p.Dhi - p.Dlo) * [1/6, 1/2, 5/6];   % Start duties of the particles.
                       % The number of entries is the number of particles: 3 (Fig. 8 of
                       % the paper). The paper does not give the first duties. These are
                       % the centers of three equal parts of the range: 0.38, 0.54, 0.70.
p.pso_dpert = 0.005;   % Small perturbation of the Gbest particle (section IV-B). The
                       % paper gives no value. This is one P&O step, p.dD.
p.pso_tol   = 0.005;   % End test, not in the paper: each particle has |velocity| <= tol
                       % and is not more than tol from Gbest (duty)
p.pso_itmax = 20;      % Most iterations of one search, not in the paper. 20 x 3 probes
                       % fit in the store of p.Nmax = 64 samples.
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
p.gwo_D0    = p.Dlo + (p.Dhi - p.Dlo) * [1/6, 1/2, 5/6];   % Start duties of the wolves,
                       % the same as the PSO. The number of entries is the number of
                       % wolves, at least 3. UNVERIFIED: 3 wolves at fixed, equally spaced
                       % duties is the report of a later paper of the same authors (IEEE
                       % Trans. Energy Convers. 32(1), 2017), read through a secondary
                       % check and not in docs/references/.
p.gwo_itmax = 10;      % Iterations in which a goes from 2 to 0. Value of this project:
                       % 10 x 3 probes = 1.2 s of search.
p.gwo_tol   = 0.005;   % End test, value of this project: each wolf is not more than
                       % tol from the alpha wolf (duty)

%% Random numbers of PSO and GWO (gmppt_rand.m)
p.rng_seed  = 12345;   % Start value of the generator, an integer from 1 to 2^31 - 2
cfg.mppt = p;
end
