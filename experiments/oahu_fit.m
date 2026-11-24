%OAHU_FIT Statistics of cloud edges from the Oahu Solar Measurement Grid.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 3.1). The
%   script reads the 1 s global horizontal irradiance (GHI) of the 17
%   LI-200 sensors of the grid and fits the values of the moving-edge
%   model of src/config/cloud_events.m.
%
%   Data: Sengupta, M.; Andreas, A. (2010). Oahu Solar Measurement Grid
%   (1-Year Archive): 1-Second Solar Irradiance; Oahu, Hawaii (Data). NREL
%   Report No. DA-5500-56506. http://dx.doi.org/10.5439/1052451. Now at
%   https://midcdmz.nlr.gov (National Laboratory of the Rockies). The
%   data is publicly accessible (OpenEI lists it under Creative Commons
%   Attribution 4.0, so each use must cite the source above). The daily
%   files are large, so they stay in data/oahu/txt (not in git). Get the monthly zip files from
%   https://midcdmz.nlr.gov/oahu_archive/rawdata/Oahu_GHI/YYYYMM.zip and
%   unzip them into data/oahu/txt. This script used 2010-07, 2010-10,
%   2011-01 and 2011-04.
%
%   Method.
%   1. Clear-sky index kt = GHI / GHIcs. GHIcs is the model of Haurwitz
%      (1945), GHIcs = 1098 cos(Z) exp(-0.057/cos(Z)), with the solar
%      zenith Z of the NOAA equations. For each sensor and month, kt is
%      divided by the median kt of the quiet clear samples (standard
%      deviation of GHI over 60 s below 5 W/m^2 and kt > 0.8), so that the
%      clear sky gives kt = 1. Only samples with Z < 70 deg are used.
%   2. Edges at each sensor. A ramp is a run of samples in which kt moves
%      in one direction by more than 0.02 each second. A ramp with a total
%      change of more than 0.3 is a cloud edge. Its values: the change,
%      the 10 % to 90 % duration, the largest rate [W/m^2/s] and the kt
%      at its low end (the shade depth).
%   3. Cloud velocity. For each window of 120 s in which at least 8
%      sensors see an edge, the lag of the largest cross-correlation of kt
%      is found for each pair of sensors (lags to 90 s, refined by a
%      parabola). A plane edge that moves with the slowness vector s gives
%      lag_ij = (r_j - r_i) . s. A least-squares fit over the pairs with a
%      correlation of 0.8 or more gives s. The window is kept if at least
%      10 pairs fit with R^2 >= 0.8. Speed = 1/|s|. This is the method
%      of cross-correlation of sensor pairs of Bosch, Zheng and Kleissl,
%      Solar Energy 87, 2013, pp. 196-203, extended to all the pairs.
%   4. Edge width. In a window with a velocity, the width of each edge is
%      its 10 % to 90 % duration times the speed.
%   5. Cloud enhancement: the largest kt of each day, and the fraction of
%      the samples with kt > 1.05.
%
%   Outputs in the folder "results": oahu_fit.mat (statistics only),
%   oahu_fit.txt, fig_oahu_fit.png.

clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir  = fullfile(projectDir, 'results');
dataDir = fullfile(projectDir, 'data', 'oahu', 'txt');
files   = dir(fullfile(dataDir, '*.txt'));
assert(~isempty(files), 'No data in %s. See the help text of this script.', dataDir);

% Sensors: columns 5 to 23 of the files. Columns 13 and 15 are tilted
% sensors and are not used. Positions from the instrument page of the site.
col = [5 6 7 8 9 10 11 12 14 16 17 18 19 20 21 22 23];
nm  = {'DH3', 'DH4', 'DH5', 'DH10', 'DH11', 'DH9', 'DH2', 'DH1', 'AP6', 'AP1', 'AP3', 'AP5', 'AP4', ...
       'AP7', 'DH6', 'DH7', 'DH8'};
lat = [21.31236 21.31303 21.31357 21.31183 21.31042 21.31268 21.31451 21.31533 21.30812 21.31276 ...
       21.31281 21.30983 21.31141 21.31478 21.31179 21.31418 21.31034];
lon = -[158.08463 158.08505 158.08424 158.08554 158.0853 158.08688 158.08534 158.087 158.07935 ...
        158.08389 158.08163 158.08249 158.07947 158.07785 158.08678 158.08685 158.08675];
lat0 = mean(lat); lon0 = mean(lon);
x = (lon - lon0) * 111320 * cosd(lat0);     % East [m]
y = (lat - lat0) * 110540;                  % North [m]
nS = numel(col);
pr = nchoosek(1:nS, 2);                     % Sensor pairs
dX = x(pr(:, 2)) - x(pr(:, 1)); dY = y(pr(:, 2)) - y(pr(:, 1));

E  = struct('amp', {}, 'dur', {}, 'rate', {}, 'low', {}, 'up', {}, 'day', {}, 't', {}, 's', {});
Vw = struct('day', {}, 't', {}, 'spd', {}, 'dir', {}, 'r2', {}, 'np', {}, 'width', {});
CE = zeros(0, 3);                           % [day, max kt, fraction kt > 1.05]
SD = [];                                    % Shade durations [s]: falling edge to the next rising edge
nOK = 0;                                    % Sensor-seconds of daylight that the edge search saw
t0 = tic;
for f = 1:numel(files)
    A = readmatrix(fullfile(dataDir, files(f).name), 'FileType', 'text');
    A(A < -9000) = NaN;
    sec = A(:, 1); yr = A(1, 2); doy = A(:, 3); hm = A(:, 4);
    hr  = floor(hm / 100) + mod(hm, 100) / 60 + sec / 3600;     % HST [h]
    % The logger stamps the end of each minute in hhmm with seconds 0 to 59.
    G   = A(:, col);
    cz  = cosZenith(doy, hr, lat0, lon0, -10);
    Gcs = 1098 * cz .* exp(-0.057 ./ max(cz, 0.05));
    ok  = cz > cosd(70) & all(isfinite(G), 2);
    kt  = G ./ Gcs;
    kt(~ok, :) = NaN;
    % Scale each sensor so that quiet clear samples give kt = 1.
    sd = movstd(G, 61, 0, 1);
    for s = 1:nS
        q = ok & sd(:, s) < 5 & kt(:, s) > 0.8;
        if nnz(q) > 300, kt(:, s) = kt(:, s) / median(kt(q, s)); end
    end
    day = yr * 1000 + doy(1);
    CE(end+1, :) = [day, max(kt(:), [], 'omitnan'), mean(kt(ok, :) > 1.05, 'all')]; %#ok<SAGROW>

    % 2. Edges at each sensor.
    edgeT = cell(1, nS); edgeD = cell(1, nS); edgeS = cell(1, nS);
    nOK = nOK + nnz(isfinite(kt));
    for s = 1:nS
        k = kt(:, s); d = [0; diff(k)];
        mv = sign(d) .* (abs(d) > 0.02); mv(isnan(mv)) = 0;
        j = 1; n = numel(k);
        while j < n
            if mv(j) == 0, j = j + 1; continue, end
            j2 = j; while j2 < n && mv(j2 + 1) == mv(j), j2 = j2 + 1; end
            a = k(j - 1); b = k(j2);
            if abs(b - a) > 0.3 && isfinite(a) && isfinite(b)
                seg = k(j - 1:j2); amp = b - a;
                lv1 = a + 0.1 * amp; lv9 = a + 0.9 * amp;
                tt = (0:numel(seg) - 1)';
                t1 = crossT(tt, seg, lv1); t9 = crossT(tt, seg, lv9);
                rate = max(abs(diff(G(j - 1:j2, s))));
                E(end+1) = struct('amp', amp, 'dur', max(t9 - t1, 0.5), 'rate', rate, 'low', min(a, b), ...
                                  'up', max(a, b), 'day', day, 't', hr(j), 's', s); %#ok<SAGROW>
                edgeT{s}(end+1) = j; edgeD{s}(end+1) = max(t9 - t1, 0.5); edgeS{s}(end+1) = sign(amp);
            end
            j = j2 + 1;
        end
        % Shade durations: each falling edge to the next rising edge, if no
        % gap in the data lies between them and the shade is shorter than 30 min.
        jd = find(edgeS{s} < 0);
        for q = jd
            nu = find(edgeS{s}(q + 1:end) > 0, 1);
            if isempty(nu), continue, end
            a1 = edgeT{s}(q); a2 = edgeT{s}(q + nu);
            if a2 - a1 < 1800 && all(isfinite(k(a1:a2))), SD(end+1) = a2 - a1; end %#ok<AGROW>
        end
    end

    % 3. Velocity in windows of 120 s.
    W = 120; L = 90;
    for w0 = 1:W/2:size(kt, 1) - W
        idx = w0:w0 + W - 1;
        if any(~ok(idx)), continue, end
        nE = sum(cellfun(@(e) any(e >= w0 & e < w0 + W), edgeT));
        if nE < 8, continue, end
        lag = nan(size(pr, 1), 1); cc = lag;
        for q = 1:size(pr, 1)
            a = kt(idx, pr(q, 1)); b = kt(idx, pr(q, 2));
            [c, lg] = xcorr(b - mean(b), a - mean(a), L, 'coeff');
            [cm, im] = max(c);
            if im > 1 && im < numel(c)
                dl = 0.5 * (c(im - 1) - c(im + 1)) / (c(im - 1) - 2 * c(im) + c(im + 1));
            else
                dl = 0;
            end
            lag(q) = lg(im) + dl; cc(q) = cm;
        end
        use = cc >= 0.8 & abs(lag) < L - 1;
        if nnz(use) < 10, continue, end
        M = [dX(use)' dY(use)']; sv = M \ lag(use);
        res = lag(use) - M * sv; r2 = 1 - sum(res.^2) / sum((lag(use) - mean(lag(use))).^2);
        if r2 < 0.8 || norm(sv) == 0, continue, end
        spd = 1 / norm(sv);
        dirn = mod(atan2d(sv(1), sv(2)), 360);           % Direction of motion, degrees from north
        % Edge widths in this window.
        wd = [];
        for s = 1:nS
            in = edgeT{s} >= w0 & edgeT{s} < w0 + W;
            wd = [wd, edgeD{s}(in) * spd]; %#ok<AGROW>
        end
        Vw(end+1) = struct('day', day, 't', hr(w0), 'spd', spd, 'dir', dirn, 'r2', r2, 'np', nnz(use), ...
                           'width', wd); %#ok<SAGROW>
    end
    fprintf('%s: %d edges, %d velocity windows so far (%.0f s)\n', files(f).name, numel(E), numel(Vw), toc(t0));
end

%% Statistics
amp = [E.amp]; dur = [E.dur]; rate = [E.rate]; low = [E.low]; up = [E.up];
dn  = amp < 0;
spd = [Vw.spd]; dirn = [Vw.dir]; wid = [Vw.width];
pc  = @(v) prctile(v, [5 25 50 75 95]);
fid = fopen(fullfile(resDir, 'oahu_fit.txt'), 'w');
out = @(varargin) cellfun(@(h) fprintf(h, varargin{:}), {1, fid}, 'UniformOutput', false);
out('oahu_fit.m, %s. %d days, %d sensors.\n', char(datetime('now')), numel(files), nS);
out('Edges (|change of kt| > 0.3): %d, %d down and %d up\n', numel(E), nnz(dn), nnz(~dn));
out('  Percentiles 5/25/50/75/95:\n');
out('  change of kt (down)       %s\n', mat2str(pc(-amp(dn)), 3));
out('  10-90 duration [s]        %s\n', mat2str(pc(dur), 3));
out('  largest rate [W/m^2/s]    %s\n', mat2str(pc(rate), 4));
out('  kt in the shade (low end) %s\n', mat2str(pc(low), 3));
out('  kt in the light (high end)%s\n', mat2str(pc(up), 3));
out('Velocity windows: %d (R^2 >= 0.8, >= 10 pairs)\n', numel(Vw));
out('  speed [m/s]               %s\n', mat2str(pc(spd), 3));
out('  direction of motion [deg] median %.0f (circular), 25-75 %%: %s\n', circMedian(dirn), mat2str(prctile(mod(dirn - circMedian(dirn) + 180, 360) - 180 + circMedian(dirn), [25 75]), 3));
out('  edge width [m]            %s (%d edges)\n', mat2str(pc(wid), 3), numel(wid));
out('Edge rate: %.1f edges per sensor-hour of daylight (Z < 70 deg)\n', numel(E) / (nOK / 3600));
out('Shade duration [s]          %s (%d spells)\n', mat2str(prctile(SD, [5 25 50 75 95]), 3), numel(SD));
out('Cloud enhancement: largest kt of a day %s, fraction kt > 1.05 median %.4f\n', mat2str(pc(CE(:, 2)), 3), median(CE(:, 3), 'omitnan'));
fclose(fid);
fit = struct('amp', amp, 'dur', dur, 'rate', rate, 'low', low, 'up', up, 'spd', spd, 'dir', dirn, ...
             'width', wid, 'CE', CE, 'nDays', numel(files), 'sensors', {nm}, 'x', x, 'y', y, ...
             'shadeDur', SD, 'edgeRate', numel(E) / (nOK / 3600));
save(fullfile(resDir, 'oahu_fit.mat'), 'fit');

st = plot_style();
fg = figure('Position', [100 100 1100 700], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(fg, 2, 3, 'TileSpacing', 'compact');
h = {spd, 'Cloud speed [m/s]'; wid, 'Edge width [m]'; low(dn), 'kt in the shade'; dur, '10-90 % edge duration [s]'; ...
     rate, 'Largest ramp rate [W/m^2/s]'; CE(:, 2), 'Largest kt of each day'};
for k = 1:size(h, 1)
    ax = nexttile(tl); histogram(ax, h{k, 1}, 40, 'FaceColor', st.series(1, :), 'EdgeColor', 'none'); st.axes(ax);
    xlabel(ax, h{k, 2}); ylabel(ax, 'Count'); grid(ax, 'on');
end
title(tl, sprintf('Oahu Solar Measurement Grid, %d days (Sengupta and Andreas 2010)', numel(files)));
exportgraphics(fg, fullfile(resDir, 'fig_oahu_fit.png'), 'Resolution', 150);

%% Local functions
function cz = cosZenith(doy, hr, lat, lon, tz)
% Cosine of the solar zenith (NOAA General Solar Position equations).
g  = 2 * pi / 365 * (doy - 1 + (hr - 12) / 24);
eq = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g));
de = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g) + 0.000907 * sin(2 * g) ...
     - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g);
tst = hr * 60 + eq + 4 * lon - 60 * tz;
ha  = tst / 4 - 180;
cz  = sind(lat) * sin(de) + cosd(lat) * cos(de) .* cosd(ha);
end

function t = crossT(tt, k, lv)
% First time at which the series k crosses the level lv (linear interpolation).
s = sign(k - lv); j = find(s(2:end) ~= s(1:end-1), 1);
if isempty(j), t = tt(end); return, end
t = tt(j) + (lv - k(j)) / (k(j + 1) - k(j)) * (tt(j + 1) - tt(j));
end

function m = circMedian(a)
% Direction of the mean unit vector [deg].
m = mod(atan2d(mean(sind(a)), mean(cosd(a))), 360);
end
