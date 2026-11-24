%FIT_TEMPERATURE Fit the temperature parameters of the Solar Cell block to the datasheet.
%
%   Made on 2026-11-21 (docs/notes/final_test_plan.md, step 0.1). The
%   script uses the static array model src/plant/pv_array_curve.m, which
%   has the equations of the Solar Cell block. It keeps TIPH1 (the Isc
%   coefficient of the datasheet), EG (block default) and TRS1 = 0, and
%   finds the value of TXIS1 that gives the Voc coefficient of the
%   datasheet from 25 degC to 65 degC. It then prints the three
%   coefficients of the model for TRS1 = 0 to 3.
%   Copy the printed TXIS1 to pv4x4_config.m. experiments/check_bench.m
%   checks the values on the Simscape model.
%   Result on 2026-11-21: TXIS1 = 6.41. Voc -0.340 %/K, Isc +0.050 %/K,
%   Pmax -0.420 %/K (datasheet -0.34, +0.05, -0.40).

projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
cfg = pv4x4_config();
Ts  = [25 45 65];
G   = 1000 * ones(cfg.arr.Nser, cfg.arr.Npar);
f   = @(TX) tempCoef(setfield(cfg, 'mod', setfield(cfg.mod, 'TXIS1', TX)), Ts, G) - cfg.mod.cVoc_ds; %#ok<SFLD>
TX  = fzero(@(x) firstOf(f(x)), [0 10]);
fprintf('TXIS1 = %.4f\n', TX);
cfg.mod.TXIS1 = TX;
for TR = 0:3
    cfg.mod.TRS1 = TR;
    [cV, cI, cP] = tempCoef(cfg, Ts, G);
    fprintf('TRS1 = %d: Voc %.3f %%/K, Isc %.3f %%/K, Pmax %.3f %%/K\n', TR, cV, cI, cP);
end

function y = firstOf(v)
y = v(1);
end

function [cV, cI, cP] = tempCoef(cfg, Ts, G)
% Slope of the straight-line fit of each value against T, % of the 25 degC value per K.
Voc = zeros(size(Ts)); Isc = Voc; Pm = Voc;
for k = 1:numel(Ts)
    c = pv_array_curve(G, Ts(k), cfg);
    Voc(k) = c.Voc; Isc(k) = c.Isc; Pm(k) = c.gmpp(2);
end
s  = @(y) 100 * subsref(polyfit(Ts - Ts(1), y / y(1), 1), struct('type', '()', 'subs', {{1}}));
cV = s(Voc); cI = s(Isc); cP = s(Pm);
end
