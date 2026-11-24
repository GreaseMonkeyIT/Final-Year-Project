%RUN_FINAL_P4 Phase 4 of the final tests: full days on the static bench.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 7).
%   Weather: the TMYx file of Gannavaram (Vijayawada airport, WMO 431810,
%   16.53 N, 80.80 E, about 75 km from NIT Andhra Pradesh), 2011-2025,
%   from climate.onebuilding.org (data/epw, not in git). Hourly global
%   (GHI) and diffuse (DHI) horizontal irradiance and air temperature.
%   Days: in January, April, July and October, the day whose daily
%   clearness (GHI over the clear-sky GHI of Haurwitz) is nearest to the
%   median of the month.
%   Irradiance: the hourly values (mean over the hour before the stamp)
%   at the middle of each hour, linear between them. The plane of the
%   array is taken as horizontal (as in cloud_events.m).
%   Scenarios:
%     open     all groups get GHI(t)
%     morning  from 7:00 to 10:00 a building shades the panels that R1
%              shades (shading_patterns.m). They get only DHI(t).
%   Cloud spells: in each hour with an hourly clearness of 0.3 to 0.8, the
%   Oahu rate of spells (half the edge rate of results/oahu_fit.mat), at
%   most 12 in a day. Each spell: a falling edge, a shade with a duration
%   from the fit, a rising edge. Speed, direction, width and depth come
%   from the fit (cloud_events.m gives the edge model). In the shade, the
%   irradiance is multiplied by kLow/kHigh.
%   Cell temperature: NOCT model, Tc = Ta + (NOCT - 20)/800 * G, with the
%   mean G of the array.
%   Controller: one run of the full day with the sensors on. The five
%   searches with the parabolic stage and T_rescan = 0, 300 and 900 s.
%   DIRECT with the local stages 1, 2 and 4 and T_rescan = 900 s.
%   Values: energy of the day, energy of the GMPP, their ratio, searches,
%   lost energy during the searches.
%
%   Outputs in the folder "results": final_p4.mat, final_p4.csv,
%   final_p4.txt. Run experiments/oahu_fit.m and build/build_static_mex.m first.
%   FINAL_QUICK set in the environment: a smoke test with a few cases,
%   outputs in results/quick.
%   FINAL_INC set in the environment: only the variants with an INC
%   (local stages 2 and 4, p.alg = 2), outputs final_<phase>_inc.*. Added
%   on 2026-11-22 for the rerun after the fix of the INC hold.


clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
resIn = resDir;
quick = ~isempty(getenv('FINAL_QUICK'));   % Smoke test: few cases, outputs in results/quick
if quick, resDir = fullfile(resDir, 'quick'); if ~isfolder(resDir), mkdir(resDir); end, end
incOnly = ~isempty(getenv('FINAL_INC'));   % Rerun of the INC variants only (fix of 2026-11-22),
sfx = ''; if incOnly, sfx = '_inc'; end    % outputs final_<phase>_inc.*
cfg  = pv4x4_config();
logf = fopen(fullfile(resDir, ['final_p4' sfx '.txt']), 'w');
say(logf, 'run_final_p4.m, %s\n', char(datetime('now')));
Fz = load(fullfile(resIn, 'oahu_fit.mat')); fit = Fz.fit;
ef = dir(fullfile(projectDir, 'data', 'epw', '*.epw'));
assert(~isempty(ef), 'No EPW file in data/epw. See the help text.');
W = readmatrix(fullfile(ef(1).folder, ef(1).name), 'FileType', 'text', 'NumHeaderLines', 8, 'Delimiter', ',');
mo = W(:, 2); dy = W(:, 3); hrE = W(:, 4); Ta = W(:, 7); GHI = W(:, 14); DHI = W(:, 16);
lat = 16.53; lon = 80.797; tz = 5.5;
doyAll = day(datetime(2021, mo, dy), 'dayofyear');
czH = cosZen(doyAll, hrE - 0.5, lat, lon, tz);
GcsH = 1098 * max(czH, 0) .* exp(-0.057 ./ max(czH, 0.05));

%% Days
months = [1 4 7 10]; if quick, months = 4; end
days = zeros(1, numel(months));
for k = 1:numel(months)
    dd = unique(dy(mo == months(k)));
    kd = arrayfun(@(d) sum(GHI(mo == months(k) & dy == d)) / sum(GcsH(mo == months(k) & dy == d)), dd);
    [~, j] = min(abs(kd - median(kd))); days(k) = dd(j);
    say(logf, 'Month %2d: day %2d, daily clearness %.2f (median %.2f)\n', months(k), days(k), kd(j), median(kd));
end

%% Profiles and curve banks
P9 = shading_patterns(); R1 = P9(strcmp({P9.id}, 'R1')).G; shR1 = logical(kron(R1 < 1000, ones(3, 1)));   % 12 x 4
[gx, gy] = groupPoints();
rs = RandStream('mt19937ar', 'Seed', 41);
scen = {'open', 'morning'};
Vg = linspace(0, 200, 4000)';
% 8 workers: the static runs need little RAM (under 1 GiB for each worker,
% because each run loads only its own day from a file), and the CPU has 32
% logical cores. With 4 workers the phase took about 2 h (2026-11-21). 12
% workers did not fit in the RAM that was free on 2026-11-22 (about 7.7 GiB).
nW = 8;
sim_pool(nW);
bankDir = fullfile(tempdir, 'final_p4_banks'); if ~isfolder(bankDir), mkdir(bankDir); end
D = struct('mo', {}, 'dy', {}, 'scen', {}, 'tb', {}, 'file', {}, 'Pg', {}, 'nSpell', {}, 't1', {});
for k = 1:numel(months)
    sel = find(mo == months(k) & dy == days(k));
    th = hrE(sel) - 0.5;                    % Middle of each hour [h]
    gh = GHI(sel); dh = DHI(sel); ta = Ta(sel); kc = gh ./ max(GcsH(sel), 1);
    day0 = find(gh > 0, 1) - 1; day1 = find(gh > 0, 1, 'last') + 1;
    t1 = th(max(day0, 1)) * 3600; t2 = th(min(day1, numel(th))) * 3600;      % Daylight window [s]
    % Cloud spells.
    sp = struct('tc', {}, 'dur', {}, 'v', {}, 'u', {}, 'w', {}, 'rk', {});
    rate = fit.edgeRate / 2;                % Spells per hour
    for h = find(kc' >= 0.3 & kc' <= 0.8)
        n = poissrnd_(rs, rate);
        for q = 1:n
            if numel(sp) >= 12, break, end
            lows = fit.low(fit.amp < 0);
            kL = lows(randi(rs, numel(lows))); kH = max(fit.up(randi(rs, numel(fit.up))), kL + 0.3);
            th0 = fit.dir(randi(rs, numel(fit.dir)));
            sp(end+1) = struct('tc', (th(h) - 0.5 + rand(rs)) * 3600, 'dur', fit.shadeDur(randi(rs, numel(fit.shadeDur))), ...
                               'v', fit.spd(randi(rs, numel(fit.spd))), 'u', [sind(th0) cosd(th0)], ...
                               'w', max(fit.width(randi(rs, numel(fit.width))), 0.5), 'rk', kL / kH); %#ok<AGROW>
        end
    end
    % Time points of the bank: each 60 s, and each 0.1 s during the edges.
    tb = t1:60:t2;
    for q = 1:numel(sp)
        tx = (2 * sp(q).w + 9) / sp(q).v;
        for te = [sp(q).tc, sp(q).tc + sp(q).dur]
            n = min(ceil(tx / 0.1), 60);
            tb = [tb, linspace(te - tx, te + tx, n)]; %#ok<AGROW>
        end
        tb = [tb, sp(q).tc + linspace(0, sp(q).dur, 5)]; %#ok<AGROW>
    end
    tb = unique(tb(tb >= t1 & tb <= t2));
    for sc = 1:2
        Gt = zeros(numel(tb), 48); Tt = zeros(1, numel(tb));
        for j = 1:numel(tb)
            hh = tb(j) / 3600;
            g = interp1(th, gh, hh, 'linear', 0); d = interp1(th, dh, hh, 'linear', 0);
            G = g * ones(12, 4);
            if sc == 2 && hh >= 7 && hh < 10, G(shR1) = d; end
            m = ones(12, 4);
            for q = 1:numel(sp)
                s1 = sp(q); sgm = s1.w / 2.197;
                r = (gx - 3.92) * s1.u(1) + (gy - 1.98) * s1.u(2);
                f1 = 0.5 * (1 + tanh(-(r - s1.v * (tb(j) - s1.tc)) / sgm));
                f2 = 0.5 * (1 + tanh((r - s1.v * (tb(j) - s1.tc - s1.dur)) / sgm));
                m = m .* (1 - (1 - s1.rk) * mean(f1 .* f2, 3));
            end
            G = G .* m;
            Gt(j, :) = G(:)';
            Tt(j) = interp1(th, ta, hh, 'linear', 'extrap') + (cfg.mod.NOCT - 20) / 800 * mean(G(:));
        end
        I = zeros(4000, numel(tb)); Pg = zeros(1, numel(tb));
        parfor j = 1:numel(tb)
            c = pv_array_curve(reshape(Gt(j, :), 12, 4), Tt(j), cfg, Vg); %#ok<PFBNS>
            I(:, j) = c.I; Pg(j) = c.gmpp(2);
        end
        bf = fullfile(bankDir, sprintf('bank_%02d_%02d_%s.mat', months(k), days(k), scen{sc}));
        save(bf, 'I', 'Pg', 'tb', 't1', '-v7.3');
        D(end+1) = struct('mo', months(k), 'dy', days(k), 'scen', scen{sc}, 'tb', tb, 'file', bf, 'Pg', Pg, ...
                          'nSpell', numel(sp), 't1', t1); %#ok<SAGROW>
        say(logf, 'Day %02d-%02d %-7s: %d curves, %d cloud spells, %.1f h of daylight\n', months(k), days(k), ...
            scen{sc}, numel(tb), numel(sp), (t2 - t1) / 3600);
    end
end

%% Runs
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
locName = {'P&O', 'VS-INC', 'Parabolic', 'INC', 'paper ending'};
var = struct('alg', {}, 'loc', {}, 'Tr', {});
fv = final_variants();                     % Final comparison (2026-11-23), final_variant.m
for a = 1:numel(fv), for Tr = [0 300 900], var(end+1) = struct('alg', fv(a).alg, 'loc', fv(a).loc, 'Tr', Tr); end, end %#ok<SEPEX,SAGROW>
if quick, var = var([1 end]); end
if incOnly, var = var([var.loc] == 2 | [var.loc] == 4); end
job = [repelem((1:numel(D))', numel(var), 1) repmat((1:numel(var))', numel(D), 1)];
rinA = [cfg.conv.Rload cfg.conv.RL];
res = zeros(size(job, 1), 5);              % [E kWh, Eref kWh, ratio %, searches, search loss %]
t0 = tic;
parfor r = 1:size(job, 1)
    d = D(job(r, 1)); v = var(job(r, 2)); %#ok<PFBNS>
    bk = load(d.file, 'I');              % Only the bank of this day
    p = final_variant(cfg.mppt, v); p.T_rescan = v.Tr; p.rng_seed = 1001; %#ok<PFBNS>
    s = sens_draw(cfg.sens, 400 + job(r, 1));
    tt = d.tb - d.t1;
    nLog = 20000;                           % 1 s
    [Pl, ~, Pr, ~, ~, nS, Es] = static_run_mex(Vg, bk.I, d.Pg, tt, tt, tt, 0.05, tt(end), nLog, rinA, p, s);
    res(r, :) = [sum(Pl) / 3.6e6, sum(Pr) / 3.6e6, 100 * sum(Pl) / sum(Pr), nS, 100 * Es / sum(Pr)];
end
say(logf, '%d day runs in %.0f s on %d workers\n', size(job, 1), toc(t0), nW);

fid = fopen(fullfile(resDir, ['final_p4' sfx '.csv']), 'w');
fprintf(fid, 'month,day,scenario,search,local_stage,T_rescan_s,E_kWh,E_gmpp_kWh,ratio_pct,searches,search_loss_pct\n');
for r = 1:size(job, 1)
    d = D(job(r, 1)); v = var(job(r, 2));
    fprintf(fid, '%d,%d,%s,%s,%s,%d,%.4f,%.4f,%.3f,%d,%.4f\n', d.mo, d.dy, d.scen, algName{v.alg}, locName{v.loc}, v.Tr, res(r, :));
end
fclose(fid);
say(logf, '\n%-22s %6s %18s %18s %10s\n', 'Variant', 'Tr', 'open ratio/srch', 'morning ratio/srch', 'srch loss');
for v = 1:numel(var)
    x = zeros(1, 5);
    for sc = 1:2
        m = job(:, 2) == v & strcmp({D(job(:, 1)).scen}', scen{sc});
        x(2 * sc - 1) = 100 * sum(res(m, 1)) / sum(res(m, 2)); x(2 * sc) = sum(res(m, 4));
    end
    x(5) = mean(res(job(:, 2) == v, 5));
    say(logf, '%-22s %6d %10.3f/%7d %10.3f/%7d %10.4f\n', final_vname(var(v)), ...
        var(v).Tr, x);
end
save(fullfile(resDir, ['final_p4' sfx '.mat']), 'D', 'var', 'job', 'res', 'days', 'months');
fclose(logf);

%% Local functions
function [gx, gy] = groupPoints()
% Five points along each group strip (geometry of cloud_events.m).
[gx, gy] = deal(zeros(12, 4, 5));
for c = 1:4
    for q = 1:12
        gx(q, c, :) = (c - 1) * 1.96 + linspace(0.196, 1.764, 5);
        gy(q, c, :) = 3.96 - (q - 0.5) * 0.33;
    end
end
end

function n = poissrnd_(rs, lam)
% Poisson random number (Knuth), with no toolbox.
L = exp(-lam); n = 0; p = rand(rs);
while p > L, n = n + 1; p = p * rand(rs); end
end

function cz = cosZen(doy, hr, lat, lon, tz)
% Cosine of the solar zenith (NOAA General Solar Position equations).
g  = 2 * pi / 365 * (doy - 1 + (hr - 12) / 24);
eq = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g));
de = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g) + 0.000907 * sin(2 * g) ...
     - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g);
ha = (hr * 60 + eq + 4 * lon - 60 * tz) / 4 - 180;
cz = sind(lat) * sin(de) + cosd(lat) * cos(de) .* cosd(ha);
end

function say(fid, varargin)
fprintf(varargin{:});
fprintf(fid, varargin{:});
end
