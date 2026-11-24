function m = bench_metrics(t, V, P, ph, ref)
%BENCH_METRICS Values of one run of the final tests (docs/notes/final_test_plan.md, step 0.5).
%
%   m = bench_metrics(t, V, P, ph, ref) takes the logged trace of one run
%   and the reference of the irradiance profile:
%     t, V, P   time [s], array voltage [V] and power [W], column vectors
%               with a constant time step
%     ph        phase of the controller at each sample: 0 wait, 1 global
%               search, 2 local stage
%     ref       struct of the reference:
%                 ic      index of the active curve at each sample
%                 curves  struct array with the fields gmpp ([V P]) and
%                         peaks ([V P] of each local peak, one row each),
%                         from pv_array_curve.m and bench_peaks.m
%                 t0      start of the evaluation [s] (samples before t0
%                         are not counted, for example the start-up wait)
%
%   Fields of m:
%     eta       dynamic efficiency [%]: Andrean et al., Energies 11, 2018,
%               Eq. (10), the energy of the array over the energy of the
%               GMPP, from t0 to the end
%     Eref      energy of the GMPP [J]
%     Eloss     lost energy, Eref - E [J]
%     Lsearch   lost energy during the global searches [% of Eref]
%     Ltrack    lost energy in the local stage on the global peak [% of Eref]
%     Lwrong    lost energy in the local stage on a wrong peak [% of Eref]
%     nSrch     number of searches that start after t0
%     tSrchMax  longest search [s] (start of phase 1 to the start of phase 2)
%     tSrch     length of each search [s]
%     wrongEnd  true if the run ends on a wrong peak (last 0.3 s)
%     fWrong    time on a wrong peak in the local stage [% of the time after t0]
%   On a wrong peak: the local peak nearest to the operating voltage is not
%   the global peak.

dt   = t(2) - t(1);
use  = t >= ref.t0;
ic   = ref.ic(:);
Pg   = arrayfun(@(c) c.gmpp(2), ref.curves);
Pref = Pg(ic);
P    = P(:); V = V(:); ph = ph(:);

% Wrong peak at each sample of the local stage.
wrong = false(size(t));
for j = unique(ic(use))'
    c   = ref.curves(j);
    sel = use & ic == j & ph == 2;
    if size(c.peaks, 1) < 2, continue, end
    [~, ig] = max(c.peaks(:, 2));
    [~, in] = min(abs(V(sel) - c.peaks(:, 1)'), [], 2);
    wrong(sel) = in ~= ig;
end

m.Eref    = sum(Pref(use)) * dt;
E         = sum(P(use)) * dt;
m.eta     = 100 * E / m.Eref;
m.Eloss   = m.Eref - E;
loss      = (Pref - P) * dt;
m.Lsearch = 100 * sum(loss(use & ph == 1)) / m.Eref;
m.Ltrack  = 100 * sum(loss(use & ph == 2 & ~wrong)) / m.Eref;
m.Lwrong  = 100 * sum(loss(use & ph == 2 & wrong)) / m.Eref;

% Searches.
ks = find(ph == 1 & [true; ph(1:end-1) ~= 1] & use);
m.nSrch = numel(ks);
m.tSrch = zeros(1, numel(ks));
for k = 1:numel(ks)
    ke = find(ph(ks(k):end) ~= 1, 1);
    if isempty(ke), ke = numel(ph) - ks(k) + 1; end
    m.tSrch(k) = (ke - 1) * dt;
end
m.tSrchMax = max([m.tSrch 0]);
last = t > t(end) - 0.3;
m.wrongEnd = mean(wrong(last)) > 0.5;
m.fWrong   = 100 * sum(wrong(use)) / sum(use);
end
