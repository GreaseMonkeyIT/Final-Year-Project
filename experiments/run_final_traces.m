%RUN_FINAL_TRACES Waveforms of the final variants for the figures of the final report.
%
%   Made on 2026-11-23 for the final report (reports/final_review). The
%   phase scripts save values, not waveforms. This script saves the
%   waveforms that the figures show. Variants: final_variants.m (DIRECT as
%   in its paper, Idea B, Idea C, PSO and GWO with the parabolic stage, and
%   P&O and INC from start-up).
%     S  Simulink (MPPT_4x4_grp.slx): start-up, 4 s, patterns P3 and R1,
%        25 degC, sensors on (sens_draw.m), all seven variants.
%     A  Static bench: the settled samples of each search on R1 (the
%        last sample of each search probe), five searches.
%     B  Static bench: the cloud event of phase 3 with the largest change
%        of the GMPP power, all seven variants, sensors on.
%     C  Static bench: one EN 50530 ramp (P0, 30 % to 100 %, 50 W/m^2/s),
%        all seven variants, sensors on.
%     D  Static bench: one full day of phase 4 (29 April, open sky), Idea C
%        and DIRECT, T_rescan = 900 s, sensors on. Needs the day banks of
%        run_final_p4.m (in tempdir/final_p4_banks).
%
%   Output: results/final_traces.mat. Run oahu_fit.m and build_static_mex.m
%   first.

clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
cfg = pv4x4_config();
var = final_variants(true); nV = numel(var);
names = arrayfun(@final_vname, var, 'UniformOutput', false);
pats = shading_patterns(); ids = {pats.id};
rinA = [cfg.conv.Rload cfg.conv.RL];
Vg = linspace(0, 200, 4000)';

%% S: Simulink start-up runs
pidS = {'P3', 'R1'};
runs = struct('mppt', {}, 'Gsched', {}, 'Tstop', {}, 'T', {}, 'sens', {});
keyS = zeros(0, 2);
for ip = 1:numel(pidS)
    G = pats(strcmp(ids, pidS{ip})).G;
    if size(G, 1) == 4, G = kron(G, ones(3, 1)); end
    for v = 1:nV
        m = final_variant(cfg.mppt, var(v)); m.T_rescan = 0; m.rng_seed = 1001;
        runs(end+1) = struct('mppt', m, 'Gsched', [0 G(:)'], 'Tstop', 4, 'T', 25, ...
                             'sens', sens_draw(cfg.sens, 500 + ip)); %#ok<SAGROW>
        keyS(end+1, :) = [ip v]; %#ok<SAGROW>
    end
end
[out, infoS] = bench_sim('MPPT_4x4_grp', runs, projectDir);
S = struct('pat', {}, 'name', {}, 't', {}, 'P', {}, 'V', {}, 'ph', {}, 'gmpp', {}, 'Vg', {}, 'Pcurve', {});
for k = 1:numel(runs)
    ip = keyS(k, 1); v = keyS(k, 2); o = out(k);
    b = bench_curve(pats(strcmp(ids, pidS{ip})).G, 25, cfg);
    if ~isempty(o.ErrorMessage), fprintf('Run %d: %s\n', k, o.ErrorMessage); continue, end
    t = o.Ppv.Time; ph = interp1(o.ph.Time, squeeze(o.ph.Data), t, 'previous', 'extrap');
    ds = max(1, round(numel(t) / 8000));       % at most about 8000 points per run
    S(end+1) = struct('pat', pidS{ip}, 'name', names{v}, 't', t(1:ds:end), 'P', o.Ppv.Data(1:ds:end), ...
                      'V', o.Vpv.Data(1:ds:end), 'ph', ph(1:ds:end), 'gmpp', b.gmpp, 'Vg', b.Vg, ...
                      'Pcurve', b.Vg .* b.I); %#ok<SAGROW>
end
fprintf('S: %d Simulink runs in %.0f s\n', numel(runs), infoS.wall);

sim_pool(6);

%% A: settled search samples on R1
bR = bench_curve(pats(strcmp(ids, 'R1')).G, 25, cfg);
A = struct('name', {}, 'Vs', {}, 'Ps', {}, 'tEnd', {}, 'Vend', {}, 'Pend', {});
for v = 1:5
    p = final_variant(cfg.mppt, var(v)); p.T_rescan = 0; p.rng_seed = 1001;
    [Pl, Vl, ~, phl, Dl] = static_run_mex(bR.Vg, bR.I, bR.gmpp(2), 0, 0, 0, 1e-6, 4, 20, rinA, p, cfg.sens);
    Dl = Dl(:); phl = phl(:);
    k = find(phl(1:end-1) == 1 & diff(Dl) ~= 0);   % last sample before each duty change of the search
    kh = find(phl == 2, 1);
    A(end+1) = struct('name', names{v}, 'Vs', Vl(k), 'Ps', Pl(k), 'tEnd', kh * 20 * p.Tc, ...
                      'Vend', mean(Vl(end-100:end)), 'Pend', mean(Pl(end-100:end))); %#ok<SAGROW>
end
A_curve = struct('Vg', bR.Vg, 'P', bR.Vg .* bR.I, 'gmpp', bR.gmpp, 'peaks', bR.peaks);

%% B: cloud event with the largest change of the GMPP power
F  = load(fullfile(resDir, 'oahu_fit.mat'));
ev = cloud_events(F.fit, 40, 11);
dP = zeros(1, numel(ev));
for e = 1:numel(ev)
    Gs = sum(ev(e).G, 2); dP(e) = (max(Gs) - min(Gs)) / max(Gs);
end
[~, eB] = max(dP);
tb = ev(eB).t(1:5:end)'; Gt = ev(eB).G(1:5:end, :);
I = zeros(4000, numel(tb)); Pg = zeros(1, numel(tb));
parfor j = 1:numel(tb)
    b = bench_curve(reshape(Gt(j, :), 12, 4), 25, cfg); %#ok<PFBNS>
    I(:, j) = b.I; Pg(j) = b.gmpp(2);
end
B = struct('event', eB, 'name', {names}, 't', [], 'P', [], 'Pr', []);
for v = 1:nV
    p = final_variant(cfg.mppt, var(v)); p.T_rescan = 0; p.rng_seed = 1001;
    s = sens_draw(cfg.sens, 300 + 7 * eB);
    [Pl, ~, Pr] = static_run_mex(Vg, I, Pg, tb, tb, tb, 0.005, ev(eB).t(end), 40, rinA, p, s);
    B.P(:, v) = Pl(:); B.Pr = Pr(:);
end
B.t = (1:size(B.P, 1))' * 40 * cfg.mppt.Tc;

%% C: one EN 50530 ramp, P0, 30 % to 100 %, 50 W/m^2/s
sc = 0.08:0.0025:1.02;
G0 = pats(strcmp(ids, 'P0')).G;
I = zeros(4000, numel(sc)); Pg = zeros(1, numel(sc));
parfor j = 1:numel(sc)
    b = bench_curve(sc(j) * G0, 25, cfg); %#ok<PFBNS>
    I(:, j) = b.I; Pg(j) = b.gmpp(2);
end
tr = (1.0 - 0.3) * 1000 / 50;
tk = [0 10 10 + tr, 20 + tr, 20 + 2 * tr, 30 + 2 * tr];
xk = [0.3 0.3 1.0 1.0 0.3 0.3];
C = struct('name', {names}, 't', [], 'P', [], 'Pr', [], 'tk', tk, 'xk', xk);
for v = 1:nV
    p = final_variant(cfg.mppt, var(v)); p.rng_seed = 1001;
    [Pl, ~, Pr] = static_run_mex(Vg, I, Pg, sc, tk, xk, 1e-4, tk(end), 400, rinA, p, sens_draw(cfg.sens, 21));
    C.P(:, v) = Pl(:); C.Pr = Pr(:);
end
C.t = (1:size(C.P, 1))' * 400 * cfg.mppt.Tc;

%% D: one full day (29 April, open sky)
D = struct();
P4 = load(fullfile(resDir, 'final_p4.mat'), 'D');
kd = find([P4.D.mo] == 4 & strcmp({P4.D.scen}, 'open'), 1);
if ~isempty(kd) && isfile(P4.D(kd).file)
    d = P4.D(kd); bk = load(d.file, 'I'); tt = d.tb - d.t1;
    D.vars = {'Idea C', 'DIRECT'};
    for q = 1:2
        algQ = [5 3];                          % Idea C, then DIRECT
        vq = var(find([var.alg] == algQ(q), 1));
        p = final_variant(cfg.mppt, vq); p.T_rescan = 900; p.rng_seed = 1001;
        [Pl, ~, Pr] = static_run_mex(Vg, bk.I, d.Pg, tt, tt, tt, 0.05, tt(end), 20000, rinA, p, sens_draw(cfg.sens, 400 + kd));
        D.P(:, q) = Pl(:); D.Pr = Pr(:);
        D.names{q} = final_vname(vq);
    end
    D.t_h = (d.t1 + (1:size(D.P, 1))') / 3600;         % hours of the day (log step 1 s)
    D.day = sprintf('%02d-%02d %s', d.mo, d.dy, d.scen);
else
    fprintf('D: day bank not found, run run_final_p4.m first\n');
end

save(fullfile(resDir, 'final_traces.mat'), 'S', 'A', 'A_curve', 'B', 'C', 'D', 'names', 'var', 'infoS');
fprintf('Saved results/final_traces.mat\n');
