---
title: GMPPT — full method landscape, industrial practice, and viva preparation
project: Implementation of MPPT for PV Arrays Under Partial Shading Conditions
status: reference
---

# GMPPT: the full landscape, what industry actually runs, and how to defend our choice

> **Convention used throughout:** every performance figure is marked **[SIM]** (simulation
> only) or **[HW]** (measured on hardware). Vendor marketing claims are marked
> **(vendor claim)**. This distinction is the single most important habit to carry into
> the viva — most of the GMPPT literature reports [SIM] numbers and does not say so
> prominently.

---

## 0. The three sentences that matter

1. **There are seven families of solution, and only two of them are algorithms in the sense the literature implies.** The rest are hardware architecture.
2. **The cheapest and most dependable method is a periodic deterministic sweep of the P–V curve followed by a local refinement** — and this is not our opinion, it is what every major inverter manufacturer actually ships.
3. **No commercial inverter, at any scale, runs PSO, Grey Wolf, Cuckoo Search, or any other metaheuristic.** Not one could be found in any datasheet, manual, or application note. The entire metaheuristic MPPT literature has, so far as the documentation shows, zero industrial deployment.

That third point is the most valuable thing in this document. Used carefully it makes our project look industrially literate rather than naive. Used carelessly it insults a decade of our examiners' reading. Section 6 covers how to say it.

---

## 1. The seven families

### Family 1 — Modified conventional hill-climbers
*Variable step-size P&O, adaptive INC, three-point weight comparison.*

**Mechanism.** Ordinary P&O or INC with the step size adapted to |dP/dV|, plus a shading-detection trigger on a power jump.

**The honest position.** These do not solve partial shading. They converge faster and oscillate less around whichever peak they are already on. Every one of them still needs a global stage bolted on to escape a local peak. Zaki et al. (2023) report the refinement stage alone converging in **<40 ms [SIM]**, which is genuinely fast — but that is the refine, not the search.

**Cost.** 8-bit MCU. Two sensors. No training. Effectively free.

---

### Family 2 — Scanning / sweep
*Full I–V sweep, sequential scan, DIRECT (dividing rectangles).*

**Mechanism.** Sweep the duty cycle or voltage across the whole range, sample power at N points, take the best, then hill-climb from there.

**Strength.** Guaranteed to find the global peak to within the scan resolution. Deterministic. Auditable. No tuning constants, no randomness, no training. **This is what industry ships** (Section 4).

**Weakness.** Cost scales with N, and during the sweep the array is deliberately driven off the peak — a real energy loss that simulation papers do not model. GoodWe measures this cost directly at **≈8.4 Wh per scan cycle** for their product.

**Note for our literature review.** DIRECT and the load-line/power-curve-slope methods appear in review-paper taxonomies (Bidram, Davoudi & Balog 2012) but have almost no dedicated hardware-validated PV literature. They are taxonomy entries, not live research fronts. Do not over-weight them.

---

### Family 3 — Model-based / structural-prior methods
*The 0.8·Voc family, Fibonacci search, golden-section search, segmentation/window methods.* **This is our family.**

**Mechanism.** Exploit the fact that in a series string the local peaks cluster near integer multiples of roughly 0.8·Voc per module group, so the search space collapses from a continuum to a handful of candidate windows.

**Lineage — cite these, in this order:**

- **Kobayashi, Takano & Sawada (2006)**, *Solar Energy Materials and Solar Cells* — the original two-stage global-search architecture for shaded arrays.
- **Patel & Agarwal (2008)**, *IEEE Trans. Industrial Electronics* **55**(4):1689–1698 — the reference "fixed-voltage window" method that the later 0.8Voc literature benchmarks against. **Get this through the institute's IEEE subscription before writing the literature review** — it could not be retrieved openly and its exact figures should not be quoted second-hand.
- **Başoğlu, M. E. (2018/2019)**, *IEEE Trans. Industry Applications*, DOI 10.1109/TIA.2018.2885216 — the most rigorous statement of the rule **and of its limits**.

**Reported performance.** Başoğlu: **99.20% [SIM]** tracking efficiency uniform, **99.10% [SIM]** under PSC.

**The limitation we must state ourselves, before an examiner states it for us.** Başoğlu writes plainly that *"distance between two adjacent peaks is not really equal to 0.8Voc under many conditions"* and that threshold-based variants can operate unreliably. The 0.8 figure is an empirical approximation from single-diode behaviour at STC. It drifts with temperature, with module mismatch and ageing, with shading *depth* as opposed to shading *count*, and it was derived for pure series strings — not for TCT or bridge-linked topologies.

**This is the honest weakness of our method and we should own it in the limitations section.** Owning it is far stronger than being caught by it.

**Cost.** 8-bit MCU. Two sensors. Needs only the module Voc from the datasheet and the bypass-group count from the array wiring. No training data, no tuning constants.

---

### Family 4 — Metaheuristics
*PSO, Grey Wolf, Cuckoo Search, ABC, Firefly, Salp Swarm, Differential Evolution, Simulated Annealing, ACO.*

**Mechanism.** Population-based stochastic search directly on duty cycle. Covered in detail elsewhere in our notes.

**Key papers worth citing rather than the hundred that are not:**

- **Mohanty, Subudhi & Ray (2016)**, *IEEE Trans. Sustainable Energy* **7**(1):181–188 — the seminal GWO-MPPT paper, and one of the very few in this family validated on **[HW]** as well as [SIM] from the outset. 555+ citations.
- **Ishaque, Salam, Amjad & Mekhilef (2012)**, *Applied Energy* 99:414–422 — **Deterministic PSO**. Important for us: it fixes the particle count and inertia precisely because classic PSO's non-deterministic convergence time is a deployment problem. An author inside the PSO camp conceding our point.
- **Sundareswaran, Peddapati & Palani (2014)**, *IEEE Trans. Energy Conversion* — the reference Firefly paper.

**Reported performance.** Typically **94–99.9% [SIM]**, **0.05–0.8 s [SIM]**. Pamuk (2023) ranks GWO first of four at **99%, 0.22 s [SIM]**.

**The number that matters for us — from our own primary reference, Ahessab et al. (2024):**

| | [SIM] | [HW] |
|---|---|---|
| PSO | 2.7–2.8 s | **35–50 s** |
| IANN-PSO | 0.1 s | **10–15 s** |

Two orders of magnitude. This single table is the strongest evidence in our whole literature base for the claim that the cost of an MPPT search is the number of operating points physically applied and allowed to settle — not the arithmetic.

**Cost.** Floating-point DSP class (F28379D and similar throughout the literature). Requires reinitialisation on every irradiance change or the swarm searches a stale landscape. Parameter sensitivity (w, c1, c2, N, k_max) requires re-tuning per array — a portability problem noted in nearly every review.

---

### Family 5 — Soft computing
*Fuzzy logic, ANN, ANFIS, reinforcement learning.*

**Mechanism.** Learn or encode the mapping from measured conditions to the MPP.

**The structural objection, stated by Worku et al. (2023), MDPI *Sustainability* 15(14):11132:** ANN and FLC *"cannot distinguish global from local maxima without additional hardware detection."* They are not global search methods. They are estimators that must be paired with one.

**Reinforcement learning** (Youssef et al. 2020, *Sensors* 20(11):3039, DQN and DDPG) is **[SIM] only**, with no hardware validation found and no mature benchmark placing it against PSO/GWO under identical shading patterns. It is an open research front, not a settled option.

**Cost.** FP DSP or better. Training data. Retraining after module degradation or replacement.

---

### Family 6 — Hybrid two-stage
*ANN+PSO, fuzzy+P&O, scan+INC, GWO+P&O. Our baseline family.*

**Mechanism.** Coarse estimate, then local refine. Every method in this family — **and ours** — has this shape. The families differ only in what supplies the coarse estimate.

**Best-evidenced results found:**

- **Zaki et al. (2023)**, *Scientific Reports*, DOI 10.1038/s41598-023-49528-w — global scan + enhanced INC: **99.99%, <0.2 s, steady-state error <0.3% [SIM]**. Their own comparison table (Adaptive Jaya 99.84%/0.648 s; Advanced Limited Search 99.77%/0.46 s; P&O/Fuzzy/ANFIS 99.56%/1.789 s) is one of the cleanest apples-to-apples benchmarks available. **Worth reproducing.**
- **Siddique et al. (2025)**, *Scientific Reports*, DOI 10.1038/s41598-025-01816-3 — adapted P&O seeding an MPC. The clearest sim-vs-hardware pair in the field: **[SIM] 99.46% / 0.17 s** against **[HW] 97.14% / 0.23 s**, same algorithm, same paper.

**Caution to record in the review.** Almost all of this evidence is self-reported by the proposing authors. Independent third-party replication under identical shading patterns is rare. The exception is **Lin, Liu, Liu & Chen (2026)**, *J. Electrical Engineering & Technology* **21**(4):3349–3381 — 13 algorithms × 252 shading patterns × 100 runs each. Result tables are paywalled; **chase this through the library, it is the closest thing to a definitive benchmark in the field.**

---

### Family 7 — Hardware and topology
*Module-level power electronics, differential power processing, array reconfiguration.*

**This family is not an algorithm and it is the one industry actually chose.**

- **MLPE (DC optimizers, microinverters).** One MPPT per module. The multi-peak curve never forms.
- **Differential power processing.** Deline et al. (NREL), OSTI 1339516 — up to **+7% annual [SIM]**, explicitly a near-best-case bound at unity ground-coverage ratio.
- **Static reconfiguration** — Su-Do-Ku, Latin square, magic square, competence square. Physically relocate modules so no row or column repeats a shading pattern. Sagar et al. (2020), *Solar Energy*: **+11.53%** against hybrid BL-TCT at the worst-case shading instant, **+38.14%** maximum against plain TCT — small-scale **[HW]**, 36 × 3 W modules under halogen lamps.
- **Dynamic reconfiguration** via switching matrices — strictly more capable, but extra switches, extra cost, extra failure points.

**The independent field evidence, and it is sobering.** Le, Truong, Asdornwised, Chaitusaney & Benjapolakul (2023), *Energies* **16**(2):970 — 13 real rooftop stations in San Diego, 2016–2021, six with DC optimizers and seven with microinverters. Under partial shading the energy utilization ratio still fell **≈14.7%** (95% CI −27.3% to −2.0%) **even with MLPE installed**. The authors recommend that where shading is rare, a plain string or central inverter is the more appropriate choice — while noting MLPE remains worthwhile where shading is common, weighed against its cost premium. **Verified against the primary text.**

This is the only family with genuine independent multi-year field data, and what it says is that even the expensive hardware answer mitigates rather than eliminates the problem.

---

## 2. Cross-family comparison

| Family | Efficiency | Time | Controller | Needs | Determinism | Evidence quality |
|---|---|---|---|---|---|---|
| Modified conventional | n/a alone under PSC | <40 ms refine [SIM] | 8-bit | nothing | full | mostly [SIM] |
| Scanning / sweep | bounded by scan resolution | scales with N; settling-limited on [HW] | 8-bit | nothing | full | **shipping product** |
| **Model-based (0.8Voc, golden-section) — ours** | **99.1–99.9% [SIM]** | **sub-second** | **8-bit** | **Voc + bypass count** | **full** | limited [HW] |
| Metaheuristics | 94–99.9% [SIM] | 0.05–0.8 s [SIM]; **10–50 s [HW]** | FP DSP | reinit on change; per-array tuning | **none** | GWO [HW]-verified; most [SIM]-only |
| Soft computing | 99–99.6% where reported | inconsistently reported | FP DSP / GPU | training data | partial | RL is [SIM]-only |
| Hybrid two-stage | 99.5–99.99% [SIM] | <0.2–0.65 s [SIM] | 16-bit / FP DSP | varies | none if PSO inside | best [SIM]+[HW] pair |
| Hardware / topology | field: MLPE still −14.7% under shading | n/a | none | extra converters / switches | full | **only family with independent field data** |

---

## 3. The verdict: cheapest and most dependable

**Cheapest and most dependable is a periodic deterministic sweep with local refinement, on an 8-bit microcontroller, using only voltage and current sensing.**

The reasoning, in the order an examiner will accept it:

1. **Dependable means bounded worst case, not best average.** A metaheuristic has no hard bound on convergence time; a sweep does. For anything that must be certified, explained to a plant operator, or debugged in the field, a guaranteed bound beats a better average every time.
2. **Cheapest means the controller, the sensors and the engineering effort — not the flop count.** Model-based and sweep methods need an 8-bit MCU and two sensors. Metaheuristics need a floating-point DSP. Soft computing additionally needs a training pipeline and retraining after any module replacement.
3. **The real currency is applied operating points, not arithmetic.** Established by the Ahessab and Siddique sim-vs-hardware gaps above. Any method that reduces the number of points physically applied wins on hardware regardless of how elegant the arithmetic is.
4. **The added sensing requirement is usually the disqualifier.** The IANN in Ahessab et al. needs per-module irradiance — one sensor per panel. **The authors themselves flag this as the main obstacle to deployment.** A method whose prior comes from the array's own electrical measurements is deployable; one that needs added instrumentation is not.
5. **Industry's revealed preference confirms all of the above** (Section 4).

**Ahessab et al.'s own conclusion, which is the best quotation we have:** with a sufficiently accurate network output, *"the need for a stochastic search method like PSO could potentially be eliminated, making it possible to employ faster search algorithms such as P and O and INC."* An author of a PSO-hybrid paper conceding that the stochastic stage becomes unnecessary once good prior information exists. **Our method is exactly that concession taken to its conclusion — we get the prior from array topology instead of from a network, so we never need the stochastic stage at all.**

---

## 4. What the industry actually runs

### 4.1 Every major inverter ships a timed brute-force sweep

| Vendor | Feature | Interval | Default | Claim |
|---|---|---|---|---|
| **SMA** | OptiTrac Global Peak / ShadeFix | **~6 min** (SMA: "the ideal time interval is usually six minutes"; increase only if shading changes very slowly) | **On** — included in all current Sunny Boy / Tripower units | Lightly shaded ~1% below unshaded, heavily shaded ~3%; unshaded systems lose <0.1% to the scanning itself *(vendor claim)* |
| **Fronius** | Dynamic Peak Manager | "regular intervals" | On | +7% on a sunny day, one 3.3 kWp shaded residential case *(vendor claim, single case)* |
| **Huawei** | MPPT Scanning (Modbus reg. 42055) | user-set minutes | **Off** (field reports) | not quantified |
| **Sungrow** | MPPT Global Scanning | automatic or user-set | automatic | not quantified |
| **GoodWe** | Shadow Scan | 1 hr ÷ MPPT count (4 MPPT → 15 min) | **Off** | scan costs ≈8.4 Wh per cycle |
| **Solis** | MPPT Multi-Peak Scanning | 10–180 min, **default 30** | **Off** | not quantified |
| **SolaX** | Global MPPT scan | 1 h / 3 h / 4 h | **Off** | states plainly it does **not** help with fast-moving cloud shading |

**Read that table carefully. Four separate observations, each usable in the viva:**

- The mechanism is a **full-range voltage sweep** — Family 2, the crudest method in the taxonomy.
- The interval is **minutes to hours**, not milliseconds. Real shadows move on the timescale of the sun and the weather. Sub-second convergence is not the bottleneck any product is optimising.
- **No vendor documentation names PSO, GWO, Cuckoo, ACO, GA, or any metaheuristic.** Not one.
- **Several ship the feature disabled by default.** Industry's assessment of how important this problem is, expressed as a default setting.

### 4.2 The architectural lever is the one that was actually pulled

The multi-peak curve only forms when modules **within a single MPPT's domain** are non-uniformly lit. So rather than out-algorithm the problem, the industry re-partitioned the hardware so fewer trackers ever see a multi-peak curve:

- **Central inverters:** 1–2 MPPT channels for the entire multi-MW unit. Hundreds of strings combined before the MPPT sees anything. Mismatch invisible.
- **Modern multi-MPPT string inverters:** Sungrow SG350HX has **up to 16 independent MPPTs, 2 strings each**. Largest units approach one string per MPPT.
- **MLPE:** one MPPT per module. Finest possible granularity.

**The market moved decisively.** String-inverter share of utility-scale designs rose from **≈14% (Q3 2018) to ≈60% (Q4 2023)** in RatedPower's design-tool data — a proxy for market share, not a shipped-MW audit, but the direction is unambiguous and corroborated by pv magazine and Wood Mackenzie shipment rankings (Huawei and Sungrow, both string-first, led H1 2025).

**State this in one line in the viva:** *the multi-peak problem is substantially an artefact of putting many mismatched modules on one tracker, and the industry's primary response was to stop doing that.*

### 4.3 Utility-scale plants barely have the problem we are solving

- **Inter-row self-shading is engineered away, not tracked around.** Single-axis trackers use **backtracking** — rotating to a deliberately sub-optimal angle near sunrise and sunset so adjacent rows never shade each other. Sandia PVPMC notes the non-linearity that makes this essential: shading as little as **10% of a string's area can cost ≈70% of its power**.
- **Soiling:** IEA-PVPS Task 13 gives a global average of **≈3–4% of annual energy**, and notes it does *not* distribute uniformly — it accumulates on the lower edge of tilted modules, so it can produce mild mismatch, not just a flat derate.
- **Cloud edges** produce transient, largely uniform drops across a tracker's footprint — a dynamic single-peak problem, not a static multi-peak one. SolaX says outright their scan does not help here.
- **NREL PV Fleet Performance Data Initiative** (8.5 GW, ~24,000 inverter channels): median availability 0.99, median degradation −0.75%/yr, median performance index 0.95. **Soiling and degradation are tracked as headline loss factors; partial shading is not broken out as a distinct fleet-level metric at all.** That absence is itself the finding.

### 4.4 No standard tests what we are optimising

- **EN 50530** measures **static** MPPT efficiency (settling on one known peak at several power levels) and **dynamic** MPPT efficiency (following one peak under ramped irradiance, ~0.5 to ~100 W/m²/s).
- **IEC 62891** is the international MPPT-efficiency counterpart. **IEC 61683** is general power-conditioner efficiency. **Sandia/CEC** measures weighted conversion efficiency across 6 power × 3 voltage levels.
- **None of them, as far as could be verified, includes a partial-shading or multi-peak test case.** All use a single PV simulator applying one uniform irradiance.

**Consequence, and it is a genuinely good viva line:** there is no standardised test that would let a customer compare two inverters' shading recovery the way EN 50530 lets them compare conversion efficiency. There is therefore **no market mechanism rewarding a vendor for shipping a better GMPPT** — which explains the industrial absence far better than any claim that the algorithms do not work.

### 4.5 Where fine-grained MPPT is genuinely deployed

- **Rooftop residential and small commercial** — real obstructions, and the whole commercial rationale for MLPE. Even Huawei, a string-first company, sells optimizers for shaded roofs. But the independent San Diego field study (§1, Family 7) shows MLPE mitigates rather than eliminates, and the SMA-vs-SolarEdge dispute over the University of Southern Denmark study shows both sides' marketing should be discounted.
- **Vehicle-integrated PV** — the strongest legitimate case anywhere. A car's curved roof means permanent, severe, geometry-driven partial shading of its own array. The Lightyear 0 uses **hundreds of cells across dozens of individually tracked modules with independent converters** (EPJ Photovoltaics, 2026). Note the answer even here: **more independent hardware channels, not a cleverer algorithm.**
- **Solar pumping and off-grid** — commercial controllers (e.g. Lorentz PS2) use conventional MPPT. No evidence of metaheuristics in any real product.

---

## 5. Where our project sits

Our deterministic window + golden-section tracker is **the same family as the shipping industrial solution, with the two weaknesses of that solution removed.**

| | Industrial periodic sweep | Ours |
|---|---|---|
| Search space | full range, blind | pruned to N_m windows by bypass-group count |
| Points applied | many (full sweep) | **2N_m + 7, known in advance** |
| Refinement | hill-climb (oscillates forever) | golden-section (terminates at a set tolerance) |
| Determinism | full | full |
| Controller | 8-bit | 8-bit |
| Trigger | timer, every 6 min–4 h | same, or on ΔP detection |

That is a defensible, industrially literate contribution: **we are not proposing a fashionable algorithm nobody deploys, we are reducing the cost of the one thing industry actually does.**

And the comparison against PSO and IANN-PSO is now the right experiment for the right reason — not "our method beats a strawman", but **"the published state of the art costs 10–15 s on hardware and needs one irradiance sensor per panel; the deployed state of the art is a blind sweep; here is a method with the deployability of the second and better cost than both."**

### The golden-section argument, stated properly

Golden-section shrinks the bracket by a fixed factor of 0.618 per evaluation, so reaching a given tolerance takes a **known number of steps and then terminates**. P&O never terminates — it oscillates around the peak indefinitely, and that oscillation is precisely where its steady-state loss comes from. Replacing P&O with golden-section in the refinement stage is the actual technical contribution, and it is the part to lead with.

---

## 6. Anticipated viva questions, with answers

**Q. Why not just use PSO? It is the standard approach for this problem.**
It is the standard *published* approach. It is not deployed in any commercial inverter we could find documentation for. PSO's cost is N × k_max applied operating points — typically 60 to 100 — and each one requires the converter to settle before the measurement is valid. Ahessab et al. measure 35–50 s on hardware for plain PSO against 2.7 s in simulation. Our method bounds the cost at 2N_m + 7 points, known before the run starts.

**Q. Your method assumes peaks sit near multiples of 0.8·Voc. What if they do not?**
Then it degrades, and we say so in the limitations. Başoğlu states directly that the spacing is not really 0.8·Voc under many conditions. It drifts with temperature, module mismatch, ageing, and shading depth, and the rule was derived for pure series strings. Our mitigation is that the windows are given finite width rather than treated as points, so the coarse scan tolerates displacement up to half a window before it misranks. The failure mode is real and it is silent, which is why we widen rather than narrow.
*(If we have time before submission, the experiment that would close this properly is to sweep the peak displacement in simulation and report the window width at which ranking fails.)*

**Q. Why golden-section rather than P&O for refinement?**
P&O does not terminate. It oscillates around the peak forever, and that oscillation is its steady-state loss. Golden-section reduces the bracket by 0.618 per evaluation, so it reaches a stated tolerance in a known number of steps and stops. Determinism in the refine stage is what lets us state a total cost in advance.

**Q. How do real solar farms handle this?**
Two ways, neither of them a clever algorithm. First, architecturally: modern string inverters carry up to sixteen independent MPPT channels with one or two strings each, so a multi-peak curve rarely forms in the first place — and string inverters went from about 14% to about 60% of utility-scale designs between 2018 and 2023. Second, when a multi-peak curve does form, a timed full-range sweep — SMA's OptiTrac Global Peak on a roughly six-minute cycle, GoodWe's Shadow Scan, Solis every thirty minutes by default. Several vendors ship it switched off by default.

**Q. So is this problem even real?**
At well-sited utility scale, largely not — inter-row shading is handled geometrically by backtracking, and NREL's fleet data tracks soiling and degradation as the material loss factors without breaking out partial shading at all. The problem is real in three places: rooftop with genuine obstructions, off-grid and pumping installations sited without the luxury of choosing the ground, and vehicle-integrated PV, where the vehicle's own curvature shades the array permanently. Our method targets the small, cheap, deterministic end of that space, which is where those applications actually sit.

**Q. Why does everyone publish metaheuristics if nobody ships them?**
Partly because they generalise — PSO needs no knowledge of array topology and no training, so it works on any array, which makes it easy to publish on. But the more concrete reason is that no test standard measures the thing they improve. EN 50530, IEC 62891 and the Sandia/CEC protocol all test tracking of a single peak under uniform irradiance. There is no certified figure for shading recovery, so there is no market mechanism rewarding a manufacturer for a better global tracker.

**Q. What is the difference between your work and the previous batch's project?**
Their window stage adapts the step size around a peak; ours fixes the number and location of probe windows from the count of series bypass groups, so the search is global under partial shading and its cost is bounded in advance. Their refinement is P&O; ours is golden-section, which terminates.
*(Confirm this against their actual report before the viva — the description of their window stage is currently an inference.)*

**Q. Your results are simulation. Why should we believe them?**
We should not believe them past what they are. Every figure in the comparison is marked simulation or hardware, and the two are never mixed in the same column. The literature's own sim-to-hardware gap is the reason: Siddique et al. report the same algorithm at 99.46% and 0.17 s in simulation against 97.14% and 0.23 s on the bench, and Ahessab et al. show a two-order-of-magnitude time gap for PSO. Our method's advantage is in applied operating points, which is a count rather than a time, and a count transfers from simulation to hardware unchanged. That is why we chose it as the primary metric.

**Q. What would you do differently with more time?**
Build the hardware stage and report measured tracking time, and construct the adversarial case — a partially shaded array with module mismatch and a temperature gradient, where the 0.8·Voc windows are displaced enough that our coarse scan misranks and PSO still finds the peak. Showing where our method loses is what would make the comparison honest.

---

## 7. Sources

**Foundational**
- Kobayashi, Takano & Sawada (2006), *Sol. Energy Mater. Sol. Cells* — two-stage MPPT under partial shade
- Patel & Agarwal (2008), *IEEE Trans. Ind. Electron.* 55(4):1689–1698 — **obtain via institute IEEE access**
- Başoğlu (2018/2019), *IEEE Trans. Ind. Appl.*, DOI 10.1109/TIA.2018.2885216 — improved 0.8Voc GMPPT and its limits
- Mohanty, Subudhi & Ray (2016), *IEEE Trans. Sustain. Energy* 7(1):181–188 — GWO, [HW] validated
- Ishaque, Salam, Amjad & Mekhilef (2012), *Applied Energy* 99:414–422 — Deterministic PSO
- Sundareswaran, Peddapati & Palani (2014), *IEEE Trans. Energy Convers.* — Firefly

**Benchmarks and reviews**
- Lin, Liu, Liu & Chen (2026), *J. Electr. Eng. Technol.* 21(4):3349–3381, DOI 10.1007/s42835-026-02665-4 — 13 algorithms × 252 patterns × 100 runs. **Paywalled; chase through library.**
- Bollipo, Mikkili & Bonthagorla (2020), *IET Renew. Power Gener.*, DOI 10.1049/iet-rpg.2019.1163 — **paywalled; chase through library**
- Worku et al. (2023), *Sustainability* 15(14):11132, DOI 10.3390/su151411132
- Zaki et al. (2023), *Sci. Rep.*, DOI 10.1038/s41598-023-49528-w
- Siddique et al. (2025), *Sci. Rep.*, DOI 10.1038/s41598-025-01816-3 — best [SIM] vs [HW] pair
- Pamuk (2023), *Energies* 16(8):3358

**Field evidence and cost**
- Le et al. (2023), *Energies* 16(2):970, DOI 10.3390/en16020970 — 13 rooftop stations, MLPE under real shading
- Deline et al., NREL, OSTI 1339516 — differential power processing
- Sagar, Pathak, Gaur & Jain (2020), *Solar Energy* — Su-Do-Ku reconfiguration
- IEA-PVPS Task 13, *Soiling Losses — Impact on Performance of PV Power Plants* (2022)
- NREL PV Fleet Performance Data Initiative, OSTI 2318550

**Industrial practice**
- SMA, *Using shadows effectively* (OptiTrac Global Peak) — sma-sunny.com
- SMA ShadeFix product page; SMA STP CORE1 datasheet
- Fronius Dynamic Peak Manager product page
- Huawei Smart I-V Curve Diagnosis datasheet; SUN2000 Modbus register documentation
- Sungrow SG350HX product page; Sungrow EMEA Academy, *Instructions for MPPT Global Scanning*
- GoodWe, *Shadow Scan Function* technical note
- Solis, *MPPT Multi-peak Scanning*; SolaX knowledge base, *How does Global MPPT scan work*
- Sandia PVPMC — *Single Axis Tracking* (backtracking); *CEC Inverter Test Protocol*
- pv magazine (Nov 2023), *Quiet shift from central to string inverters in utility-scale solar*
- RatedPower, *The rise of string inverters*; Mayfield Renewables, *Central vs String Inverters for Utility-Scale PV*
- EPJ Photovoltaics (2026) — vehicle-integrated PV module architecture under dynamic shading

**Standards**
- EN 50530 — overall efficiency of grid-connected PV inverters (static and dynamic MPPT efficiency)
- IEC 62891:2020 — MPPT efficiency of grid-connected PV inverters
- IEC 61683:1999 — power conditioners, procedure for measuring efficiency

---

## 8. Gaps to close before submission

1. **Patel & Agarwal (2008)** — obtain the primary text through institute IEEE access. Do not quote its figures second-hand.
2. **Lin et al. (2026)** and **Bollipo et al. (2020)** — the closest things to a definitive benchmark and a definitive critical review. Both paywalled. Worth a library request.
3. **The previous batch's report** — confirm exactly what their window stage does before claiming a differentiator.
4. **IEC 62891 scope** — confirm whether it contains any partial-shading test case. The claim that no standard tests multi-peak performance is strong and should be verified against the actual standard text, not a secondary description.
