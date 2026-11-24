function st = gmppt_init(p)
%GMPPT_INIT State of the global search at the start of a search.
%
%   st = gmppt_init(p) returns the state that gmppt_search.m uses. p is
%   the mppt struct of pv4x4_config. mppt_controller.m calls this function
%   once at start-up and again before each new search (restart).
%
%   All the methods use the same struct, so that Simulink Coder sees one
%   fixed type. Each method uses only some of the fields. Every field has
%   a fixed size. The sample arrays have the size of p.Drep (1 x p.Nmax).
%   The particle arrays have the size of p.pso_D0 and p.gwo_D0.
%
%   Fields for the controller and for logging:
%     np        search probes applied so far
%     end_kind  stage that the method asks for after the hand-over, used
%               only if p.paper_end = 1:
%               0 shared local stage, 1 P&O with the step end_step,
%               2 hold the duty (see mppt_controller.m)
%     end_step  duty step of the P&O for end_kind = 1
%     cert      certificate ratio of the ceiling check (gmppt_ceiling.m)
%     certAll   largest ceiling of all the gaps / best power
%
%   Fields that the controller sets after this function, before the first
%   call of a restart (the PSO start of Ishaque et al. uses them if
%   p.pso_reinit = 1):
%     re        true: this search is a restart
%     Dprev     duty at the time of the restart
%     Pprev     power before the change that started the restart [W]
%     Pnow      power at the time of the restart [W]

z = zeros(size(p.Drep));

% Interface and log.
st.np       = 0;
st.end_kind = 0;
st.end_step = 0;
st.cert     = 0;
st.certAll  = 0;

% Restart data from the controller.
st.re    = false;
st.Dprev = 0;
st.Pprev = 0;
st.Pnow  = 0;

% Sample store. Entry k is the k-th sample that the search took.
st.n   = 0;        % Samples in the store
st.D   = z;        % Duty
st.V   = z;        % Voltage [V]
st.I   = z;        % Current [A]
st.P   = z;        % Power [W]
st.lev = z;        % DIRECT: level of the interval. Its length is L0 / 3^lev
st.ord = z;        % Indices of the samples in the order of rising duty
st.ib  = 0;        % Index of the sample with the highest power

% Sequence control, for all the methods.
st.stage = 0;      % 0 before the first call. Then each method sets its own value
st.mode  = 0;      % Idea B: 0 DIRECT part, 1 ceiling check
st.Dp    = 0;      % Duty of the probe that the converter has now

% DIRECT (gmppt_direct.m).
st.a   = 0;              % Lower end of the sampling interval
st.L0  = 0;              % Length of the sampling interval
st.qD  = zeros(1, 3);    % Duties of the probes that wait
st.qL  = zeros(1, 3);    % Levels of the probes that wait
st.qn  = 0;              % Entries of qD that are used
st.qi  = 0;              % Entry of qD that the converter has now
st.c19 = false;          % Result of Eq. (19) for the first three samples
st.c20 = false;          % Result of Eq. (20) for the first three samples
st.jid = 0;              % Interval that the extra samples of the shading test divided
st.gx  = 0;              % Extra global cycles done (0 to 2)

% Random numbers (gmppt_rand.m), for PSO and GWO. The generator starts
% from p.rng_seed. At a restart, mppt_controller.m copies the state of the
% last search into the new st, so each search gets new numbers (changed on
% 2026-11-22: before, each search started again from p.rng_seed).
st.rng = p.rng_seed;

% Particles of PSO and wolves of GWO.
st.it  = 0;                        % Iterations done
st.ip  = 0;                        % Particle or wolf that the converter has now
st.x   = zeros(size(p.pso_D0));    % PSO: position (duty) of each particle
st.v   = zeros(size(p.pso_D0));    % PSO: velocity (duty step) of each particle
st.fit = zeros(size(p.pso_D0));    % PSO: power of each particle in this iteration [W]
st.pb  = zeros(size(p.pso_D0));    % PSO: best position of each particle
st.pbP = zeros(size(p.pso_D0));    % PSO: power at pb [W]
st.gb  = 0;                        % PSO: best position of all the particles
st.gbP = 0;                        % PSO: power at gb [W]
st.wx   = zeros(size(p.gwo_D0));   % GWO: position (duty) of each wolf
st.wfit = zeros(size(p.gwo_D0));   % GWO: power of each wolf in this iteration [W]
st.lD   = zeros(1, 3);             % GWO: duties of the alpha, beta and delta wolves
st.lP   = zeros(1, 3);             % GWO: powers of the alpha, beta and delta wolves [W]
end
