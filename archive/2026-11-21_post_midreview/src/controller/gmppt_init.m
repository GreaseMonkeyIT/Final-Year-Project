function st = gmppt_init(p)
%GMPPT_INIT Empty state of the global search in gmppt_search.m.
%
%   st = gmppt_init(p) returns the state at the start of a search. p is
%   the mppt struct of pv4x4_config. Call it again to start a new search.
%
%   All arrays have the size of p.Drep (1 x p.Nmax). p.Drep has a fixed
%   size, so the arrays have a size that is known at compile time, as
%   Simulink Coder requires.
%
%   Fields:
%     ph       phase of the search (see gmppt_search.m)
%     g        cycles done in the globally biased stage of DIRECT
%     np       search probes applied
%     nI       DIRECT intervals. Ilo, Ihi: ends. Ic: centre (the sampled
%              duty). Iv, Ii, Ip: V, I and P at the centre. Idead: the
%              interval is dead after a skip rule, or has no sample
%              (Ip = -1, p.alg = 6). Itag: 2 or 3 for the thirds s2 and
%              s3 of the first trisection, 4 for a third that skip rule 3
%              or 4 of p.alg = 6 keeps undivided, else 0. The intervals
%              are in order of rising duty.
%     ns       samples of all probes. Sd, Sv, Si: duty, V, I, in order of
%              rising duty. Ideas B and C use these.
%     px, pv   PSO (p.alg = 7): positions and velocities of the
%              particles. pbx, pbp: personal bests. gx, gp: global best.
%              pit: iterations done. rs: state of the random generator.
%     q        duties of the probes that the last plan step queued (at
%              most 8).
%              qv, qi: their measured V and I. qn: number queued.
%              qk: number applied.
%     tP, tW   index and third-width of the interval of a trisection
%              that waits for its two samples (tP = 0: none)
%     Dhand    duty at the hand-over to P&O

z = zeros(size(p.Drep));
st.ph = 0;
st.g  = 0;
st.np = 0;
st.nI = 0;
st.Ilo = z; st.Ihi = z; st.Ic = z;
st.Iv  = z; st.Ii  = z; st.Ip = z;
st.Idead = false(size(z));
st.Itag  = z;
st.ns = 0;
st.Sd = z; st.Sv = z; st.Si = z;
st.q  = zeros(1, 8); st.qv = zeros(1, 8); st.qi = zeros(1, 8);
st.qn = 0;
st.qk = 0;
st.tP = 0;
st.tW = 0;
st.tSkL = false;                 % Skip rule 1 or 2 on the right or left child
st.tSkR = false;
st.c19 = false;                  % p.alg = 6: results of the shading test
st.c20 = false;
st.pa = 0; st.pb = 0;            % p.alg = 6: duties of the pair of the second test
st.pVhi = 0; st.pIlo = 0;        % and V of its high-voltage, I of its low-voltage sample
st.lastW = 0;                    % p.alg = 6: new spacing of the last local division
z8 = zeros(1, 8);                % p.alg = 7 (PSO), at most 8 particles:
st.px = z8; st.pv = z8;          % position (duty) and velocity
st.pbx = z8; st.pbp = z8;        % personal best duty and power
st.gx = 0; st.gp = 0;            % global best duty and power
st.pit = 0;                      % iterations done
st.rs = 0;                       % state of the random generator
st.Dhand = p.Dstart;
end
