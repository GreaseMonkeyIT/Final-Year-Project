---
title: Prior-art reading notes for Ideas B and C
date: 2026-10-22
status: working notes, one section for each paper
---


Questions per paper: Q1 search variable. Q2 monotone I-V / bound form. Q3 search pattern.
Q4 stop rule or certificate. Q5 hand-over. Q6 validation, cost.

## xu2021mmpt (IEEE TIE 68(1) 2021) - READ IN FULL
- Q1: array voltage, continuous sweep through the converter (buck-boost 20 kHz). Voltage loop.
- Q2: uses monotonic decreasing I-V. Bounds come from STC constants plus best power:
  Vrange,min = P_GMPP / I_GMPP,STC,array (left of this V, P < P_GMPP because I <= I_GMPP,STC).
  Irange,min = P_GMPP / (0.9 Voc,STC,array) (once I drops below this while sweeping right, V < 0.9 Voc_STC so P < P_GMPP).
  Bound is a single global region (power contour vs STC rectangle), NOT a per-gap bound from two measured neighbours.
- Q3: sequential sweep: right until I <= Irange,min, then left until V <= Vrange,min if Vini > Vrange,min.
- Q4: ends when the excluded regions cover the rest. Claims guarantee that GMPP is tracked "under all conditions".
- Q5: hand-over to INC at V_GMPP.
- Restart: |dP| > Pth plus fixed period Tth (both).
- Q6: sim + hardware (Chroma 62150H-600S, 5 series modules, TMS320F28335, buck-boost). Scan time and energy loss vs MPT and GS.
- Needs: Voc_STC_array, I_GMPP_STC_array (datasheet). Derived from Furtado 2018 MPT.
- Relevance: same physical fact as our bound (I non-increasing in V). Different use: global exclusion with datasheet constants inside a sweep. Ours: local rectangle V1*I2 from two measured samples inside an interval search.

## wang2016ssj (IEEE TIE 63(1) 2016) - READ (sections II to IV)
- Q1: string voltage, sequential IncCond perturbation upward from 0.6 Voc_mod to Vend = 0.9 Voc_string.
- Q2: EXACT SAME INEQUALITY as ours, used predictively. At a section-dividing point A1 (current = Isc(j+1), measured), jump to V_B1 = Pm / Isc(j+1). Between A1 and B1: V < V_B1 and I < Isc(j+1), so P < Pm. i.e. P <= V(high end) * I(low-voltage end) <= Pm.
  Also heuristics: Imj ~ 0.9 Iscj (judge uses 0.85), Vmj ~ (j - 0.24) Voc/n.
- Q3: sequential: search (IncCond to a local PPP), skip (jump by the equipower line), judge (I_B1 > 0.85 Isc and dp/dv sign). Repeats per module.
- Q4: ends when Pm / Isc > Vend (0.9 Voc string). Correctness relies on 0.85 factor heuristic for the judge step, not only on the bound.
- Q5: stays on GMPP with IncCond.
- Restart: every 15 min, and |Pin - Pm| / Pm > 0.1.
- R-GMPPT variant needs n current sensors (bypass diode currents).
- Q6: experiments, string of modules. Sampling 0.01 s.
- Relevance: prior art for the bound itself. It uses it to choose the next voltage in a one-way sweep. It does not keep a set of gaps, does not pick the gap with the highest bound, and does not certify every gap before hand-over.

## bharadwaj2021rpc (IEEE Access 9, 2021) - READ (sections I, II)
- Q1/Q2: "rectangles" = predicted local-peak powers P_i = K_i * alpha * Isc * i * beta * Voc. K_i = shading factor of module i from module voltage sensing and a fitted bypass-diode model. GMPP = argmax_i (i K_i).
- Needs distributed per-module voltage sensors, offline diode regression, alpha and beta factors. Then P&O for exact tracking.
- Not a bound. A model-based prediction of peak powers. No interval search. Not prior art for the measured ceiling, but a reviewer may confuse the word "rectangle". Cite to distinguish.

## boztepe2014rvw (IEEE TIE 61(7) 2014) - READ (sections II, III)
- Q1: string voltage reference (inverter input, PI voltage loop). Grid of probe voltages v = V1 + k*VGSTEP, VGSTEP in [0.5, 1.0] VocP (VocP = Voc per bypass group).
- Q2: SAME INEQUALITY, measured form. Power operating triangle (POT) under line p = I*v. After measuring point 1 with current I1, new lower limit Vmin1 = Pstore / I1: every voltage above V1 and below Vmin1 has I <= I1, so P < Pstore. Upper limit fixed at 0.9 Voc (from 2000 random Simulink cases). First window uses ISC_STC.
- Q3: one-way scan on a fixed voltage grid. Grid points inside the excluded part are skipped.
- Q4: ends when the window is exhausted. Then P&O from the best sample.
- Restart: fixed timer (15 min cited) and sudden-change detector on dP/dV vs k*Ipv.
- Q6: Simulink (10 x OST-80, 2 bypass diodes each) and experiments.
- Relevance: the earliest journal use (2014) of the measured-current skip. Our ceiling V1*I2 is the two-sided version for a gap between two samples.

## furtado2018mpt (IEEE TIE 65(4) 2018) - SCANNED (sections II, III)
- Maximum power trapezium from STC: V <= 0.9 Voc_STC, I <= I_GMPP_STC, P <= P_GMPP_STC. Vrange,min = P_GMPP / I_GMPP_STC updated during an up-then-down voltage scan. Base of xu2021mmpt. Needs datasheet constants. Sequential sweep.

## li2019lipo (IEEE Access 7, 2019) - READ (sections III, IV start)
- Q1: boost DUTY cycle, range 0.1 to 0.9. f(x) = measured power.
- Q2: Lipschitz upper bound curves (sawtooth), constant k = 1500 chosen from simulations of the 3S array (k must exceed the max slope. Derived from dP/dV x Voc).
- Q3: CLOSEST GMPPT ANALOG OF IDEA C. Start at xmin and xmax, then always evaluate at the argmax of the upper bound (UBmax) instead of LIPO's random point. This is Piyavskii-Shubert in duty space.
- Q4: stop at N iterations or when the change in x is below 0.3 % to 1 %. No bound-based certificate.
- Q5: output xg. Restart when |Pn - Pmax| / Pmax > 2 %.
- Q6: simulation (5 ms control cycle) and experiments (50 ms cycle), 3S array, boost converter. Compared with modified PSO and modified firefly.
- Weakness to cite: k is a tuned constant. If the true slope exceeds k, the bound is invalid and the GMPP can be missed. If k is large, the search is slow.
- Relevance to C: same "endpoints first, then sample where the ceiling is highest" structure. Differences for C: ceiling from two measured (V, I) samples, needs no constant, is valid by physics for any series-parallel array with bypass diodes. C splits at the midpoint (the rectangle ceiling has no interior argmax). C stops by a certificate (no gap ceiling above (1+eps) best, or gap narrower than tol).

## ahmed2023skip (IEEE TPEL 38(9) 2023) - READ (section II)
- Q1: voltage reference, left to right from 0.45 Voc_mod.
- Q2: skip zones from the 0.8 Voc_mod peak spacing (peaks 0.83 to 1.18 Voc_mod apart, from 10 patterns). Stop rule Imin = Pbest / Vmax with Vmax = 0.9 Voc_array (from Xu et al.): if I < Imin, no GMPP to the right. Global bound with a fixed Vmax, not a two-sample gap bound.
- Q3: hill-climb to first peak, jump, scan zone, stop scanning a zone after one peak, jump. Sequential.
- Q4/Q5: P&O at Vbest with an oscillation detector (ODP <= 3 in 5 steps, then hold). Restart if |P - Pbest| / Pbest >= 5 %.
- Q6: sim + experiment, buck-boost with PI voltage loop. 1.02 s average convergence.
- Relevance: same family as Xu (fixed-limit global exclusion) plus a peak-spacing model. Not prior art for the gap ceiling or best-first selection.

## kermadi2019hybrid (IEEE TIE 66(9) 2019) - SCANNED (sections I, II)
- PSO hybrid. Uses the SSJ skip of wang2016ssj: skipped interval [V_SDP, V_skip], V_skip = P_best / I_SDP (eq. 8), "the operating power is always lower than" P_best inside it. Also stops particles from re-searching intervals that another particle already explored. PV array simulator prototype.
- Relevance: the measured skip inside a population search. Not a gap-wise ceiling over all sample pairs, no best-first rule, no certificate.

## kermadi2021rapid (IEEE TIE 68(3) 2021) - SCANNED (sections I, II)
- Upward, downward and skip processes over zones with a VGSTEP grid (after Furtado 2018). Vmin from the MPT idea (projected power). New skip scheme discards a voltage section without the GMPP. Compared with MPT and flower pollination. Experimental.
- Relevance: same sweep-and-skip family.

## tiong2017binary (CENCON 2017, conference) - READ IN FULL (body text font-shifted, decoded)
- Q1: boost DUTY cycle (direct control, no PI), 3-module string, Simulink only.
- Q2: NO physics bound. Classic binary search: compare the power at the middle with a "target" that is "the next higher value the search can achieve", updated each iteration. The half that is judged not to hold the target is dropped. This assumes the comparison tells the side of the peak, i.e. unimodal behaviour.
- Q3: halve the bracket each step. Two thresholds: threset (expand boundaries by a fixed proportion after a large power change) and thmp (stop to avoid oscillation).
- Q4: stop by thmp. No certificate. Paper reports BSA trapped at a local peak in at least one test case, and capped at the boundary in others. PSO found the true MPP in more of the 10 cases than BSA.
- Q6: simulation only, 10 shading cases, one sample per iteration (vs 3 for PSO), faster than PSO.
- Cites earlier uniform-irradiance binary-search MPPT: Shiota et al. ICEMS 2013 (binary search with converter ripple), Phan-Tan and Nguyen-Quang ICSET (P&O based on binary searching), Marquez et al. CPE-POWERENG 2016 (binary search MPPT for high-power PV).
- Relevance to C: same word "binary search" and same "eliminate the region where the MPP cannot lie" phrase. But the elimination is a power comparison, not a bound, so it can drop the global peak. C keeps every gap whose measured ceiling can beat the best, and drops a gap only when physics proves it cannot. C does not discard half the range per step.

## kumaresan2022secant (ECCE 2022, conference) - READ (sections I, II)
- Q1: bisection on the POWER LEVEL, not on duty or voltage. Bracket [pmin, pmax] = [0, P_GMPP at STC].
- Q2: no I-V bound. For each p_mid, a secant search over voltage tries to reach P = p_mid. If reachable, pmin = p_mid, else pmax = p_mid.
- Q4: stop when |pmax - pmin| < 2 % of P_STC (design choice).
- Q6: MATLAB-Simulink only, vs SSJ.
- Needs P_STC of the string.
- Relevance: a bisection with a 2 % tolerance in GMPPT, but on a different variable and with a reachability test instead of a ceiling. Not structural prior art for C. Useful contrast.

## ramana2018bisection (eTechNxT 2018, conference) - SCANNED (sections II, III)
- Zones at multiples of 0.9 Voc_total / N_bypass. Probe each zone, build estimated I and P arrays. Bisection is used as a root finder for the DUTY that gives a target voltage between dmin and dmax, not as a partition of the search space by a bound. dSpace 1006 experiment, 4 x 1 array.
- Relevance: low. Shares the word "bisection" only.

## abujarad2026prism (IEEE TPEL 41(11) 2026) - READ (sections I to III, IV start)
- STRONGEST PRIOR ART FOR THE B AND C STRUCTURE (best-first + bound + certificate) in GMPPT.
- Q1: DUTY. Seeds D = 0.4, 0.6, 0.8 (setup-dependent, "lower, middle, upper portions"). UIC/PSC test from current consistency of the high-duty seeds.
- Q2: bounds from an explicit LOGISTIC I-V SURROGATE, calibrated offline (irradiance-dependent parameters), per "layer" (bypass segment). Optimistic layer bound uses a proxy short-circuit current from the nearest discovered layer, justified by "an unknown layer cannot exceed the current of an already-discovered neighbor" (the monotone current fact, applied per layer).
- Q3: constrained best-first branch-and-bound over layers. Sample classification (plateau / knee / higher layer), adaptive duty BLOCKS (block width = MPP duty range / number of modules), candidate queue sorted by descending power bound, next probe targets the leading candidate's plateau.
- Q4: terminate when no candidate layer bound exceeds the best discovered peak. Claims "the GMPP has been identified with certainty" and "guaranteeing that no higher power layer is overlooked" (certainty is conditional on the model and the block placement).
- Q5: phase B: logistic model, dP/dV = 0, secant to V_mpp, latch duty, monitor |P - Pt| / Pt <= 5 %. Re-entry on disturbance, reusing the seeds.
- Q6: hardware, Chroma 62150H simulator, buck-boost, 5 PSC patterns, GMPP in 0.20 to 0.35 s, settle 0.30 to 0.55 s, 99.76 to 99.96 %.
- Needs: logistic calibration, module count, layer boundaries Vstart,m and Voc,m, duty range of MPPs.
- Relevance: B and C both share "best-first by bound, stop when no bound beats the best". Our difference: the ceiling is computed from two raw measured samples per gap (no model, no calibration, no module count, no layer identification), so its validity does not depend on a fitted model. C's pattern is plain bisection of gaps, not layer-targeted probes. B attaches the certificate to a simplified form of the published DIRECT (correction of 2026-11-08, see `Notes/idea_B_theory_and_baselines.md`, section 5.1).

## nguyen2010direct (IEEE TIE 57(10) 2010) - READ (sections II to IV)  [BASE OF IDEA B]
- Q1: DUTY of a buck-boost (Rpv = eta (1-D)^2/D^2 Rload). Absolute interval from Voc_min/max, Isc_min/max, Rload_min/max (eqs 13 to 18).
- Q2: argues p(v) is Lipschitz (eqs 7 to 10), so DIRECT applies with an unknown constant. POI rule (11), (12) with epsilon = 0.03 in global mode (sensor error 1.5 % each, power 3 %), epsilon = 0 in local mode. No monotone-current bound anywhere.
- PSC test from the first 3 samples: (ID3 - ID1)/ID3 >= 0.1 and (VD2 - VD1)/VD2 >= 0.2 (eqs 19, 20), from Impp ~ 0.9 Isc and Vmpp ~ 0.8 Voc.
- Q3: globally biased DIRECT: divide only the POI with the largest length. 9 samples in 3 iterations (intervals 1/9 of 0.3 to 0.5 duty wide, i.e. 0.03 to 0.05). Skip rules: V < Voc/3, I < Isc/3, V > 0.9 Voc, and the (19)/(20) same-stair tests.
- Q4 (KEY FOR B): switch to local mode when "the two samples that have the highest powers are consecutive": then "the GP's region is CONSIDERED to be found". If not consecutive, two more global cycles. This is a heuristic, not a bound or certificate. Our misses (6 to 12 %) happen exactly here.
- Local mode: trisect the interval with the highest centre power until the step < dcr (eq 21, 22: tabs = 3n x S). Then P&O with step dcr.
- Q6: hardware, buck-boost C = 470 uF, L = 1.5 mH, 20 kHz, sampling 0.05 s. Only compared with Patel and Agarwal 2008.
- Relevance: B replaces the heuristic "two best are consecutive -> region found" with the measured gap check before the hand-over.
- Correction (2026-11-08): the DIRECT inside B (`mppt.alg = 3`) is a simplified form of this paper, not every step as published. It treats the case where only one of (19), (20) holds as uniform (the paper takes more samples and tests again, p. 3459). It marks a whole third dead under skip rules 1 and 2 (the paper skips only the outer sample, p. 3461) and has no rules 3 and 4. Its local stage stops one trisection earlier than Eq. (21). `mppt.alg = 6` follows the paper (`Notes/idea_B_theory_and_baselines.md`, section 5.1).

## low2011ispacs (ISPACS 2011, conference) - SCANNED (sections I to III)
- Same group as nguyen2010direct. DIRECT for RAPIDLY CHANGING INSOLATION (single-peak case), against dP-P&O. Same POI and area-dividing description. Simulation and experiment.
- Relevance: second DIRECT tracker. Not about partial shading, no bound, no certificate.

## jones2021direct25 (J Glob Optim 79(3) 2021, author PDF) - READ (sections 2.1, 2.2, 3.15, 4)
- DIRECT's only stop rules: iteration limit T or evaluation budget (Step 6). No optimality certificate.
- Convergence is "everywhere dense". Key quote for B (section 2.1): to do better, "one must assume more about the objective function than mere continuity", e.g. "knowledge of the functional form that would enable computing lower bounds over subregions". The monotone PV current is such knowledge (upper bounds over subintervals for maximisation).
- POI = rectangles with the lowest Lipschitz lower bound f(ci) - K di for SOME K > 0, and better than fmin by epsilon |fmin| (eps = desired accuracy, typically 1e-4).
- Section 2.3: weaknesses (slow refinement. Search around local minima delays the global one. No use of local trends. High dimension. Rigid partition). Section 3: variants (DIRECT-l, restart, PLO, MrDIRECT, ADC, BIRECT, DIRECT-GL, DIRMIN, eDIRECT, HD-DIRECT). 3.15: constraints, noise (Deng and Ferris, conference only), hidden constraints.
- Lists nguyen2010direct as the PV application.

## nesic2013shubert (Automatica 49(3) 2013, accepted version) - READ (sections 1 to 3)
- Shubert algorithm restated: F_k(u) = min_j (y_j + L |u - u_j|), M_k = max F_k, next input u_{k+1} = argmax F_k (upper envelope). Needs L >= L_min known ("we assume that L is known"). Larger L = slower. Rate O(1/k). Theorem: lim y_k = y*.
- Extremum seeking form: piecewise-constant input held for a WAITING TIME T, sample output, Shubert picks the next input. Result: semi-global practical convergence to the global extremum for dynamic plants as T grows. SISO focus (multi-input versions need 2^m evaluations). Numerical example only.
- Relevance: (1) gives the closed-loop justification for any "hold duty, wait for settling, measure, choose next duty" global search (our 20 ms probe = waiting time). (2) Shows Shubert's rule needs a known constant. C replaces the Lipschitz envelope with the measured monotone-current rectangle.

## khong2013unified (Automatica 49(9) 2013, accepted version) - READ (sections 1 to 3)
- Sampled-data extremum seeking framework for a broad class of optimisers. Key Assumption 7: the optimiser must be robust to BOUNDED ADDITIVE MEASUREMENT PERTURBATIONS |w_k| <= delta (converges to a nu-neighbourhood of the global minimisers).
- Three algorithms shown to satisfy it: Piyavskii-Shubert (1-D, known L, eq. 8), DIRECT with a MODIFIED TERMINATION CRITERION (from "Khong et al. 2013"), and Strongin's Global Search Algorithm.
- Plain DIRECT samples a dense set, so only a subsequence approaches the optimum. "this renders DIRECT unsuitable for the purpose of extremum seeking control". The modified DIRECT stops in finite time and then HOLDS the input.
- Relevance to B: prior art for "DIRECT + a termination rule + hold the input" in a control loop. B's stop test differs: it uses measured V and I to certify every gap, not an epsilon on DIRECT's own quantities. Need the modified-termination paper to compare exactly.
- Relevance to noise: gives the formal notion (robustness to additive measurement error) that our 0.5 % noise test should be phrased against.

## khong2013directes (Automatica 49(7):1970-1978, 2013, accepted version) - READ (sections 1, 3.1)  [CLOSEST PRIOR ART FOR B's STOP TEST]
- DOI 10.1016/j.automatica.2013.04.006. Conference version: khong2012directes (AUCC 2012).
- Problem stated: plain DIRECT samples densely, so after it finds the basin it still leaves it forever. "A sensible termination procedure ... which guarantees a point within a certain neighbourhood of a global optimum has been sampled, is needed."
- Their fix (section 3.1): with a KNOWN Lipschitz constant L, the lowest value on rectangle j is Q(u_j) - L d_j (d_j = centre-to-vertex distance). "A less heuristic stopping criterion for DIRECT can then be y_i being within some tolerance of the bound, as is the case for Piyavskij-Shubert." Then terminate and HOLD the best input. Robustness to bounded additive perturbations, waiting time tuning, semi-global practical convergence in finite time. Multi-unit extension. Simulation only.
- Relevance to B: the IDEA of a bound-based certificate to stop DIRECT is published (2013). B's difference: (1) bound from measured V and I with the monotone-current property, NO Lipschitz constant. (2) B does not only test, it SPLITS every gap that fails and samples more. (3) bound is per gap between neighbouring samples (rectangle V1 x I2), not per DIRECT rectangle around a centre. (4) applied to the truncated PV DIRECT of Nguyen and Low. (5) evaluated for GMPPT miss rate.

## sergeyev2006diagonal (SIAM J Optim 16(3) 2006, arXiv) - READ (sections 1, 2 start)
- ADC: samples at the TWO VERTICES of the main diagonal (in 1-D: the two interval ends), efficient diagonal partition (trisection reusing vertices), set of Lipschitz constants, new lower-bound procedure over hyperintervals, two-phase local/global balance.
- KEY QUOTE FOR B: "it is difficult to apply for DIRECT some meaningful stopping criterion, such as ... stopping on achieving a desired accuracy in solution. This happens because DIRECT does not use a single estimate of the Lipschitz constant but a set of possible values of L." In practice DIRECT stops when the budget is exhausted.
- Relevance to C: end-point sampling of intervals is the diagonal approach in 1-D. C uses end points too, but bisects instead of trisects.

## chiter2005sampling (AMC 2005, preprint "Toward a new DIRECT algorithm. A two-points based sampling method") - SCANNED (section 1)
- One-dimensional DIRECT variant: BISECTION with samples at 1/3 and 2/3 of each interval, reused by the children. Motivated by DIRECT's slow convergence when the minimiser lies on the boundary.
- Relevance to C: 1-D halving form of DIRECT (2005). C differs by sampling the interval ends and by using a measured ceiling instead of potential optimality.

## stripinis2024halrect (J Glob Optim 88(1) 2024, arXiv) - SCANNED (abstract, section 1)
- HALving RECTangles: bisection plus up to 2n+1 sample points per hyper-rectangle, reuse in children, four new selection strategies, unknown Lipschitz constant.

## stripinis2024empirical (J Glob Optim 88(3) 2024, arXiv) - SCANNED (section 2.3)
- Compares partition schemes: trisection (DIRECT), single-longest-side trisection, diagonal trisection (ADC, two vertices), diagonal BISECTION (BIRECT: two points on the diagonal at 1/3 and 2/3, because "neither sampling at the center nor the diagonal's endpoints are appropriate for bisection" in n-D). In 1-D, end-point bisection reuses both ends, so the n-D objection does not apply to C.

## zhou2022single (IEEE TIE 69(3) 2022) - SCANNED (sections I, II)
- Single sensor (converter output side). Extends MPT and SSJ to the DUTY domain: lower and upper duty limits plus skipping duty sections without the GMPP, using equipower lines and the monotonic output current vs load power. Sequential.
- Relevance: same sweep-and-skip family, in duty. Not a gap ceiling, no best-first.

## aquib2020time (IEEE TPEL 35(1) 2020) - SCANNED (sections I, II)
- Time-based: uses the SETTLING TIME of Vpv to a voltage reference to detect the current-source region (CSR) and skip it. Probes near multiples of 0.8 Voc_module. Not a power bound.
- Relevance: low for B and C.

## sun2023ovs (IEEE TSTE 14(1) 2023) - SCANNED (abstract, section I)
- Optimized voltage search: search areas from M-MPT + SDP + SSJ, multiple forward and optional backward passes that skip more intervals. Compared with 7 skip-family methods. Sim + experiment.
- Relevance: the most developed sweep-and-skip method. Same physical facts, sequential pattern. Not a gap ceiling, not best-first, no certificate.

## hadiby2026ssr (IEEE JESTPE 14(3) 2026) - SCANNED (abstract, section II)
- Search space reduction optimisation adapted to MPPT: random agent generation for exploration and a progressive shrinking of the duty search range, midpoint update removed, one tuning parameter. dSPACE 1104 + PV emulator. 3.175 s convergence.
- Relevance: stochastic range shrinking. Not a bound, not best-first, no certificate. Not prior art for B or C beyond the phrase "search space reduction".

## NOT OBTAINED IN FULL TEXT (paywall without institute access, or CAPTCHA)
- piyavskii1972, shubert1972 (SIAM, no access): algorithm read through nesic2013shubert and khong2013unified, which restate it exactly.
- jones1993direct (Springer, no access): algorithm read through jones2021direct25 (section 2.1) and nguyen2010direct (section III).
- gablonsky2001local, paulavicius2018birect (Springer, no access): read through jones2021direct25 and stripinis2024empirical.
- ScienceDirect (Elsevier) showed a CAPTCHA, so the Elsevier versions were not fetched. Author copies were used instead (Melbourne repository).
