function [st, D, fin] = gmppt_pso(st, p, V, I)
%GMPPT_PSO One step of the PSO search of Ishaque et al. (2012).
%
%   [st, D, fin] = gmppt_pso(st, p, V, I) follows the interface of
%   gmppt_search.m. Source: K. Ishaque, Z. Salam, M. Amjad and
%   S. Mekhilef, "An improved particle swarm optimization (PSO)-based MPPT
%   for PV with reduced steady-state oscillation," IEEE Trans. Power
%   Electron., vol. 27, no. 8, pp. 3627-3638, 2012. The equation and
%   figure numbers below are those of this paper.
%
%   The position of a particle is a duty. The velocity is a duty step.
%   The power of the array is the fitness. One probe measures one
%   particle. One iteration measures all the particles in turn (Fig. 8).
%
%   Steps:
%     1. Start. The particles start at the duties p.pso_D0, with zero
%        velocity (Fig. 8). The paper does not give the first duties, so
%        p.pso_D0 is a value of this project. With p.pso_reinit = 1, a
%        restart uses the rule of the paper in place of p.pso_D0:
%          d_new = d_old - (P_old - P) / K1                    Eq. (16)
%          K1 = p.pso_K1 if the power fell, p.pso_K1 / 2 if it rose
%                                                              Eq. (17)
%          start duties: d_new - K2, d_new, d_new + K2         Eq. (19)
%        d_old, P_old and P come from the controller (st.Dprev, st.Pprev,
%        st.Pnow).
%     2. After each iteration, the best position of each particle (Pbest)
%        and the best position of all the particles (Gbest) are updated.
%        In the first iteration, the start duties are the Pbest values.
%     3. Velocity and position of each particle, Eqs. (12) and (13):
%          v = w v + c1 r1 (Pbest - d) + c2 r2 (Gbest - d)
%          d = d + v
%        r1 and r2 are random numbers in (0, 1) from gmppt_rand.m. The
%        position stays in [p.Dlo, p.Dhi].
%     4. Small perturbation (section IV-B). A particle with a velocity of
%        exactly zero gets the velocity p.pso_dpert. This occurs for the
%        Gbest particle in the second iteration, because all three terms
%        of Eq. (12) are zero for it.
%     5. End. The paper has no end test: the velocities become almost
%        zero and the duty stays constant. This function ends the search
%        when each particle has |v| <= p.pso_tol and is not more than
%        p.pso_tol from Gbest, or after p.pso_itmax iterations, or when
%        the store has no space for one more iteration. The hand-over
%        duty is Gbest. The paper then holds this duty, so the search
%        reports st.end_kind = 2. The controller uses it only if
%        p.paper_end = 1.
%
%   The store (st.D, st.V, st.I, st.P) keeps each probe for the record.
%   The search does not read it.

fin = false;
Np  = numel(st.x);

% First call: start positions.
if st.stage == 0
    st.rng = p.rng_seed;
    if p.pso_reinit == 1 && st.re
        K1 = p.pso_K1;                     % The power fell (decreasing insolation)
        if st.Pnow > st.Pprev
            K1 = 0.5 * p.pso_K1;           % The power rose
        end
        dn = st.Dprev - (st.Pprev - st.Pnow) / K1;
        for i = 1:Np
            st.x(i) = dn;                  % All the particles at the new duty
        end
        st.x(1)  = dn - p.pso_K2;          % The two outer particles are moved
        st.x(Np) = dn + p.pso_K2;
    else
        for i = 1:Np
            st.x(i) = p.pso_D0(i);
        end
    end
    for i = 1:Np
        st.x(i)   = min(max(st.x(i), p.Dlo), p.Dhi);
        st.v(i)   = 0;
        st.pb(i)  = st.x(i);
        st.pbP(i) = 0;
    end
    st.gb    = st.x(1);
    st.gbP   = 0;
    st.it    = 0;
    st.ip    = 1;
    st.stage = 1;
    D     = st.x(1);
    st.Dp = D;
    st.np = st.np + 1;
    return
end

% Power of the particle that the converter had.
i = st.ip;
st.fit(i) = V * I;
st = gmppt_store_add(st, st.Dp, V, I, 0);
if i < Np
    st.ip = i + 1;                         % Next particle of this iteration
    D     = st.x(st.ip);
    st.Dp = D;
    st.np = st.np + 1;
    return
end

% All the particles are measured: end of one iteration.
st.it = st.it + 1;

% Pbest of each particle, then Gbest.
for i = 1:Np
    if st.it == 1 || st.fit(i) > st.pbP(i)
        st.pb(i)  = st.x(i);
        st.pbP(i) = st.fit(i);
    end
end
for i = 1:Np
    if (st.it == 1 && i == 1) || st.pbP(i) > st.gbP
        st.gb  = st.pb(i);
        st.gbP = st.pbP(i);
    end
end

% Velocity and position, Eqs. (12) and (13).
conv = true;
for i = 1:Np
    [st.rng, r1] = gmppt_rand(st.rng);
    [st.rng, r2] = gmppt_rand(st.rng);
    v = p.pso_w * st.v(i) + p.pso_c1 * r1 * (st.pb(i) - st.x(i)) ...
                          + p.pso_c2 * r2 * (st.gb - st.x(i));
    if v == 0
        v = p.pso_dpert;                   % Small perturbation of the Gbest particle
    end
    st.v(i) = v;
    st.x(i) = min(max(st.x(i) + v, p.Dlo), p.Dhi);
    if abs(v) > p.pso_tol || abs(st.x(i) - st.gb) > p.pso_tol
        conv = false;
    end
end

if conv || st.it >= p.pso_itmax || st.n + Np > numel(st.D)
    fin = true;
    D   = st.gb;
    st.end_kind = 2;                       % The paper holds the duty
    st.end_step = 0;
    return
end

st.ip = 1;                                 % First particle of the next iteration
D     = st.x(1);
st.Dp = D;
st.np = st.np + 1;
end
