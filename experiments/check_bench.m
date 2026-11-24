%CHECK_BENCH Pass gates 0.1, 0.2 and 0.3 of the test bench.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, section 3).
%     Gate 0.1  Temperature. PV4x4_sweep.slx with the uniform pattern P0 at
%               25, 45 and 65 degC. The temperature coefficients of Voc,
%               Isc and Pmax must be within 10 % of the datasheet values
%               (pv4x4_config.m, cfg.mod.c*_ds).
%     Gate 0.2  Sensors and ADC. sensor_adc.m with 2e5 samples: noise,
%               mean error and SNR of a full-scale sine against the
%               datasheet values.
%     Gate 0.3  Static array model. The GMPP of pv_array_curve.m must be
%               within 0.2 % of the GMPP of the Simscape sweep: the nine
%               patterns of shading_patterns.m at 3 temperatures and 3
%               irradiance levels (scale 1.0, 0.6 and 0.3), and the three
%               patterns of shading_patterns_grp.m at 3 temperatures on
%               PV4x4_sweep_grp.slx.
%
%   Outputs in the folder "results": check_bench.mat, check_bench.txt
%   Run the build scripts first. 4 workers (sim_pool.m).

clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
cfg  = pv4x4_config();
logf = fopen(fullfile(resDir, 'check_bench.txt'), 'w');

say(logf, 'check_bench.m, %s\n', char(datetime('now')));

%% Sweeps
pats = shading_patterns(); patg = shading_patterns_grp();
Ts = [25 45 65]; sc = [1.0 0.6 0.3];
job = struct('mdl', {}, 'G', {}, 'T', {}, 'id', {}, 'sc', {});
for k = 1:numel(pats)
    for T = Ts
        for s = sc
            job(end+1) = struct('mdl', 'PV4x4_sweep', 'G', s * pats(k).G, 'T', T, 'id', pats(k).id, 'sc', s); %#ok<SAGROW>
        end
    end
end
for k = 1:numel(patg)
    for T = Ts
        job(end+1) = struct('mdl', 'PV4x4_sweep_grp', 'G', patg(k).G, 'T', T, 'id', patg(k).id, 'sc', 1); %#ok<SAGROW>
    end
end
load_system(fullfile(projectDir, 'models', 'PV4x4_sweep.slx'));
load_system(fullfile(projectDir, 'models', 'PV4x4_sweep_grp.slx'));
sim_pool(4);
t0 = tic;
out = Simulink.SimulationOutput.empty;
for mdlName = {'PV4x4_sweep', 'PV4x4_sweep_grp'}      % parsim takes one model per call
    sel = find(strcmp({job.mdl}, mdlName{1}));
    in = Simulink.SimulationInput.empty;
    for k = sel
        s = Simulink.SimulationInput(job(k).mdl);
        s = s.setVariable('G', job(k).G, 'Workspace', job(k).mdl);
        s = s.setVariable('pv_T', job(k).T, 'Workspace', job(k).mdl);
        % The sweep must reach Voc at the coldest case: 200 V.
        s = s.setVariable('Vend', 200, 'Workspace', job(k).mdl);
        in(end+1) = s; %#ok<SAGROW>
    end
    o = parsim(in, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
               'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
    out(sel) = o;
end
say(logf, '%d sweeps in %.0f s on 4 workers\n', numel(job), toc(t0));

for k = 1:numel(job)
    o = out(k);
    job(k).err = o.ErrorMessage;
    if ~isempty(o.ErrorMessage), say(logf, 'Sweep %d: %s\n', k, o.ErrorMessage); continue, end
    V = o.Vpv.Data; I = o.Ipv.Data; keep = I > 0; V = V(keep); I = I(keep); P = V .* I;
    [Pm, j] = max(P);
    job(k).sim = struct('Voc', V(end), 'Isc', I(1), 'gmpp', [V(j) Pm]);
    c = pv_array_curve(job(k).G, job(k).T, cfg);
    job(k).st = struct('Voc', c.Voc, 'Isc', c.Isc, 'gmpp', c.gmpp);
    job(k).dP = 100 * (c.gmpp(2) - Pm) / Pm;
    job(k).dV = c.gmpp(1) - V(j);
end

%% Gate 0.1
say(logf, '\nGate 0.1: temperature coefficients, P0 at 1000 W/m^2 (Simscape sweep)\n');
sel = find(strcmp({job.id}, 'P0') & [job.sc] == 1 & strcmp({job.mdl}, 'PV4x4_sweep'));
S = [job(sel).sim];
fitc = @(y) 100 * subsref(polyfit(Ts - 25, y / y(1), 1), struct('type', '()', 'subs', {{1}}));
cV = fitc([S.Voc]); cI = fitc([S.Isc]); g = reshape([S.gmpp], 2, []); cP = fitc(g(2, :));
ds = [cfg.mod.cVoc_ds cfg.mod.cIsc_ds cfg.mod.cPmp_ds]; mo = [cV cI cP]; nm = {'Voc', 'Isc', 'Pmax'};
pass01 = true;
for k = 1:3
    d = 100 * (mo(k) - ds(k)) / abs(ds(k));
    ok = abs(d) <= 10; pass01 = pass01 && ok;
    say(logf, '  %-4s model %+.4f %%/K, datasheet %+.2f %%/K, difference %+.1f %% %s\n', nm{k}, mo(k), ds(k), d, passStr(ok));
end
say(logf, '  Pmax at 25/45/65 degC: %s W\n', mat2str(round(g(2, :), 1)));
say(logf, 'Gate 0.1 %s\n', passStr(pass01));

%% Gate 0.3
say(logf, '\nGate 0.3: static model against Simscape, GMPP difference [%%]\n');
ok = arrayfun(@(j) isempty(j.err), job);
dP = [job(ok).dP];
say(logf, '  %d cases: mean |dP| %.4f %%, max |dP| %.4f %%, max |dV| %.3f V\n', numel(dP), mean(abs(dP)), ...
    max(abs(dP)), max(abs([job(ok).dV])));
[~, w] = max(abs(dP)); jj = find(ok); w = jj(w);
say(logf, '  Worst: %s, %s, %d degC, scale %.1f: static %.2f W at %.2f V, Simscape %.2f W at %.2f V\n', job(w).mdl, ...
    job(w).id, job(w).T, job(w).sc, job(w).st.gmpp(2), job(w).st.gmpp(1), job(w).sim.gmpp(2), job(w).sim.gmpp(1));
pass03 = all(ok) && max(abs(dP)) <= 0.2;
say(logf, 'Gate 0.3 %s\n', passStr(pass03));

%% Gate 0.2
say(logf, '\nGate 0.2: sensors and ADC (sensor_adc.m, typical values)\n');
s = cfg.sens; s.on = 1; rng(1); N = 2e5;
lsb = s.FS / 2^s.bits;
% ADC alone: no sensor errors, a full-scale sine of 1 kHz sampled at 20 kHz.
a = s; a.eV = 0; a.oV = 0; a.nV = 0; a.kV = 1; a.adc_gain = 0; a.adc_off = 0; a.adc_inl = 0;
t = (0:N-1)' * 50e-6; x = s.FS / 2 + 0.499 * s.FS * sin(2 * pi * 1000 * t);
y = zeros(N, 1);
for n = 1:N, y(n) = sensor_adc(x(n), 0, randn(1, 4), a); end
e = y - x; snr = 20 * log10(rms(x - mean(x)) / rms(e));
say(logf, '  ADC SNR, full-scale sine: %.1f dB (datasheet 69.1 dB typical) %s\n', snr, passStr(abs(snr - 69.1) < 1));
say(logf, '  ADC noise: %.3f LSB rms (expected 0.508)\n', rms(e) / lsb);
% Full chain at a fixed operating point: mean error and noise.
V0 = 150; I0 = 30; Vm = zeros(N, 1); Im = Vm;
for n = 1:N, [Vm(n), Im(n)] = sensor_adc(V0, I0, randn(1, 4), s); end
yV = s.kV * V0 / s.FS;
eVexp = s.eV + s.oV / (s.kV * V0) + (s.adc_gain / 2^s.bits) + (s.adc_off + s.adc_inl * 4 * yV * (1 - yV)) * lsb / (s.kV * V0);
say(logf, '  Voltage at 150 V: mean error %+.3f %% (expected %+.3f %%), noise %.3f V rms (%.4f %%)\n', ...
    100 * (mean(Vm) / V0 - 1), 100 * eVexp, std(Vm), 100 * std(Vm) / V0);
say(logf, '  Current at 30 A:  mean error %+.3f %%, noise %.4f A rms (%.4f %%)\n', 100 * (mean(Im) / I0 - 1), std(Im), 100 * std(Im) / I0);
say(logf, '  Power noise: %.4f %% rms of the power\n', 100 * std(Vm .* Im) / (V0 * I0));
say(logf, '  Resolution: %.1f mV per LSB on Vpv, %.1f mA per LSB on Ipv\n', 1e3 * lsb / s.kV, 1e3 * lsb / s.kI);
s0 = s; s0.on = 0; [v0, i0] = sensor_adc(V0, I0, randn(1, 4), s0);
pass02 = abs(snr - 69.1) < 1 && v0 == V0 && i0 == I0;
say(logf, '  Switch off: exact values returned %s\n', passStr(v0 == V0 && i0 == I0));
say(logf, 'Gate 0.2 %s\n', passStr(pass02));

save(fullfile(resDir, 'check_bench.mat'), 'job', 'cfg', 'mo', 'ds', 'snr', 'pass01', 'pass02', 'pass03');
fclose(logf);

function s = passStr(ok)
if ok, s = 'PASS'; else, s = 'FAIL'; end
end

function say(fid, varargin)
% Print to the command window and to the log file.
fprintf(varargin{:});
fprintf(fid, varargin{:});
end
