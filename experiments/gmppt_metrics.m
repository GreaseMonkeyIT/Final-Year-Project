function r = gmppt_metrics(r, o, g, Tstop)
%GMPPT_METRICS Values of one run of MPPT_4x4.slx for the global-search tables.
%
%   r = gmppt_metrics(r, o, g, Tstop) adds the fields below to the struct
%   r. o is one Simulink.SimulationOutput of MPPT_4x4.slx, g is the sweep
%   entry of the pattern that is active at the end of the run
%   (results/pv4x4_sweeps.mat) and Tstop is the stop time [s].
%
%     t, V, P, D, ph  logged signals (ph: 0 wait, 1 search, 2 local stage)
%     nSearch   search probes of the first search (0 for P&O and INC)
%     tSearch   time from the first probe to the hand-over [s]
%     tHand     time of the hand-over, or of the start of tracking [s]
%     Dhand     duty at the hand-over
%     pctHand   power in the second half of the first local period, % of the GMPP
%     Pend      final power, mean of the last 0.3 s [W]
%     Vend      final voltage, mean of the last 0.3 s [V]
%     Vswing    peak-to-peak voltage in the last 0.3 s [V]
%     Pgmpp     power of the global peak [W]
%     pct       Pend, % of the GMPP
%     nSrch     number of searches in the run
%     tSrch     start time of each search [s]
%     t98       time after which the power stays at 98 % of Pend or more [s]
%     eff1s     mean power over the first 1 s, % of the GMPP
%     effRun    mean power over the full run, % of the GMPP
%     onPeak    'global' or 'local, <V> V': the peak nearest to Vend
%   run_gmppt_baseline.m and run_gmppt_restart_tests.m use this function.

f = {'t', 'V', 'P', 'D', 'ph', 'nSearch', 'tSearch', 'tHand', 'Dhand', 'pctHand', 'Pend', 'Vend', ...
     'Vswing', 'Pgmpp', 'pct', 'nSrch', 'tSrch', 't98', 'eff1s', 'effRun', 'onPeak'};
for k = 1:numel(f), r.(f{k}) = NaN; end
r.onPeak = '';
r.Pgmpp = g.gmpp(2);
if ~isempty(o.ErrorMessage)
    return
end

t  = o.Ppv.Time;
P  = o.Ppv.Data;
V  = o.Vpv.Data;
tD = o.D.Time;
D  = squeeze(o.D.Data);
tp = o.ph.Time;
ph = squeeze(o.ph.Data);
np = squeeze(o.np.Data);
r.t = t; r.V = V; r.P = P; r.D = D; r.ph = ph;

% Searches: each change of ph to 1.
ks = find(ph == 1 & [true; ph(1:end-1) ~= 1]);
r.nSrch = numel(ks);
r.tSrch = tp(ks)';
if isempty(ks)
    r.nSearch = 0;
    r.tSearch = 0;
    kh = find(ph == 2, 1);
else
    kh = find(ph == 2 & (1:numel(ph))' > ks(1), 1);
end
if ~isempty(kh)
    r.tHand = tp(kh);
    if ~isempty(ks)
        r.tSearch = tp(kh) - tp(ks(1));
        r.nSearch = max(np(ks(1):kh));
    end
    kd = find(tD >= r.tHand + 1e-3, 1);
    r.Dhand = D(kd);
    sel = t >= r.tHand + 0.010 & t <= r.tHand + 0.020;
    if ~isempty(ks) && any(sel)
        r.pctHand = 100 * mean(P(sel)) / r.Pgmpp;
    end
end

last = t > Tstop - 0.3;
r.Pend   = mean(P(last));
r.Vend   = mean(V(last));
r.Vswing = max(V(last)) - min(V(last));
r.pct    = 100 * r.Pend / r.Pgmpp;
kl = find(P < 0.98 * r.Pend, 1, 'last');
r.t98    = t(min(kl + 1, numel(t)));
r.eff1s  = 100 * mean(P(t <= 1)) / r.Pgmpp;
r.effRun = 100 * trapz(t, P) / (t(end) - t(1)) / r.Pgmpp;

[~, j] = min(abs(g.peaks(:,1) - r.Vend));
if abs(g.peaks(j,1) - g.gmpp(1)) < 0.5
    r.onPeak = 'global';
else
    r.onPeak = sprintf('local, %.1f V', g.peaks(j,1));
end
end
