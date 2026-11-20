# DIRECT explainer: pending edits

Items 1 to 9 were applied and published on 2026-11-21 (artifact version 4). Add new items below and apply them only when the user asks.

Page: https://claude.ai/artifact/AakEZgGYpjPyAY8745wC5P
Source: direct_explainer.html in the same scratchpad folder.

Each item marked [Added by user] comes from a question the user asked while reading. On the page, give each such addition a visible tag "Added by user" (a small label next to its heading or at the start of its block). Use the same style for every tag, set through the theme tokens.

1. Section 1, the paragraph on rescaling to [0, 1]: [Added by user]
   - Name the step "min-max normalization".
   - Give the formula z_k = (x_k − ℓ_k)/(u_k − ℓ_k) and its inverse x_k = ℓ_k + z_k(u_k − ℓ_k), each with a "where" list.
   - Explain "without loss of generality": the map is affine and one-to-one, so the minimizer and f* are the same.
   - Say why DIRECT needs it: side lengths and d_i must be comparable across variables.
   - Add the caution: the iterates depend on the chosen bounds.
   - Add "min-max normalization" and "affine map" to the glossary.

2. Section 1: add a subsection "Derivative-free optimization", after the four definitions. [Added by user]
   - Make the roles clear. f maps one input vector x to one number. The optimizer (DIRECT) searches for the x that minimizes f. f does not return the minimum.
   - "Expensive" means each evaluation of f costs a lot. DIRECT does not make an evaluation cheaper. It reduces the number of evaluations it needs.
   - "Derivative-free" describes the method, not the function. Give the three reasons derivatives are not used: not accessible (black box), not existing (kinks, discontinuities), or too costly or noisy to estimate.
   - Finite differences: a forward-difference gradient costs n + 1 evaluations, and measurement noise is divided by the step size h. Give the formula with a "where" list.
   - The families of DFO methods: direct search (Hooke-Jeeves, Nelder-Mead, pattern search), model-based (trust region, Bayesian optimization), stochastic population methods (GA, PSO), and deterministic Lipschitzian methods (DIRECT). Cite Rios and Sahinidis 2013 [11] and Conn, Scheinberg and Vicente 2009 (SIAM book).
   - Name clash: "direct search" is a family of methods. DIRECT is the acronym for DIviding RECTangles. They are not the same thing.
   - MPPT note: P&O and INC estimate dP/dV or dI/dV from consecutive measurements, so they are local finite-difference methods. DIRECT uses no derivative estimate.
   - Glossary: add "finite difference", "gradient", "direct search method", "smooth function".

3. Section 1, "Expensive evaluation": add a note that "expensive" refers to each evaluation of f, not to DIRECT. Then add DIRECT's own overhead: [Added by user]
   - Memory grows linearly with the number of evaluations m, one hyperrectangle per evaluation.
   - Selection builds the hull from one point per size level, about O(m log m) per iteration in a plain implementation.
   - Division is trivial arithmetic.
   - The overhead is negligible next to an expensive evaluation and becomes noticeable only above about 10⁵ evaluations.
   - MPPT note: a settling period lasts milliseconds and DIRECT's arithmetic is far less. The real limit is memory, hence a fixed evaluation budget and fixed-size persistent arrays for Simulink Coder.

4. Section 2, the proof: add a clarification after the proof paragraph. [Added by user]
   - The linear interpolation builds the counterexample f̃ on paper. The algorithm never computes it. A sees only its own samples, and they are identical for f and f̃.
   - With continuity alone, no finite sampling rate is enough, because a continuous dip can be arbitrarily narrow. Hence "dense in the limit", not "dense enough".
   - Determinism matters: A's sample points follow from its rules, so the counterexample can place the dip where A never samples.
   - With a Lipschitz bound, a finite spacing is enough. In 1-D, spacing h guarantees an error of at most K·h/2, so h = 2τ/K reaches tolerance τ. Give it as an equation with a "where" list. Link it to the existing Nyquist analogy (no bandlimit means no rate is enough, a bandlimit makes the Nyquist rate sufficient).

5. New subsection, in section 3 or 4: "DIRECT builds no model of f". [Added by user]
   - In practice DIRECT never fits, interpolates or predicts values between samples. Each decision uses only the center value and the size of each box. The bound f(cᵢ) − K·dᵢ over all K takes the place of a model.
   - The figures draw the true curve from the known test function. DIRECT sees only the dots. Say this in a figure caption as well.
   - The saw-tooth of Figure 3 (Piyavskii-Shubert) is a guaranteed lower envelope, not an estimate of f.
   - Contrast with model-based (surrogate) methods: quadratic interpolation in a trust region (Powell), radial basis functions, and Gaussian process regression or kriging in Bayesian optimization. Cite EGO: Jones, Schonlau and Welch, "Efficient global optimization of expensive black-box functions", J. Global Optim. 13 (1998) 455-492. Same Jones as DIRECT.
   - Surrogates also fall under the proof of section 2. A kernel assumes a smoothness, and a dip narrower than that is interpolated over and missed.
   - Advantages for DIRECT: no model to choose or get wrong, and no fitting cost (a Gaussian process costs on the order of N³ for N samples).
   - Price: no use of trends (§2.3.3). Link to the weaknesses section.
   - MPPT note: the controller holds only samples of duty cycle and power. Nothing reconstructs the P-V curve.
   - Glossary: add "surrogate model", "Gaussian process / kriging", "Bayesian optimization", "radial basis function", "trust region".

6. Section 3: expand the definition of Lipschitz continuity, and add an interactive diagram before the lower-bound equation. [Added by user]
   - Text, in the user's preferred wording: "In one dimension, take any point on the graph and draw two lines through it with slopes +K and −K. They form a double cone, like an hourglass lying on its side. The whole graph stays outside the upper and lower parts of that cone. Seen from one sample, this means f can rise or fall at most K per unit distance, which is exactly the floor f(c) − K·d that DIRECT uses."
   - Precise statement to go with it: the inequality confines the graph to the left and right wedges (the sideways hourglass, or bow tie). The upper and lower wedges are forbidden.
   - Relation to the derivative: for a differentiable f, K = sup |f′(x)|. Examples: sin x has K = 1, and x² on [0, 1] has K = 2. |x| is Lipschitz (K = 1) with a kink. √x on [0, 1] is continuous but not Lipschitz. The classes nest: bounded derivative ⊂ Lipschitz ⊂ continuous.
   - Prior contact: slew rate, and the Picard-Lindelöf theorem for ODEs. Name: Rudolf Lipschitz.
   - Expand the existing slew-rate analogy box in section 3 with the full mapping:
     - SR plays the role of K. A voltage sampled at one instant bounds the output within ±SR·Δt for the next Δt microseconds. This is the hourglass, with time on the horizontal axis.
     - Classical Lipschitz optimization is like knowing the datasheet slew rate and using it to bound the output between samples.
     - DIRECT is like knowing the amplifier has some slew limit, but not the figure. Instead of guessing one value, DIRECT keeps every box that would matter for some value of SR.
   - P-V note: K is the steepest slope of P against V, on the falling side of the knees. It is finite but unknown, because it changes with shading and temperature.
   - Interactive diagram (new Figure, canvas, uses the 1-D test function). Give the figure its own "Added by user" tag in the caption, separate from the tag on the text:
     - The user drags an anchor point along the curve (pointer drag, plus a slider for keyboard and touch).
     - A K slider. The lines of slope +K and −K pass through the anchor.
     - Shade the allowed region (left and right wedges) lightly. Shade the forbidden region (upper and lower wedges) in another light tint.
     - Draw the curve in the normal color where it obeys the bound and in a warning color where it enters the forbidden wedges. Readout: "K below the Lipschitz constant (≈ 5.9): the bound fails at N places" or "bound holds everywhere".
     - Optional toggle: show the floor f(c) − K·d for a box of half-width d around the anchor, so the link to DIRECT's bound is visible.
     - Respect prefers-reduced-motion, use theme tokens, and work at phone width.
   - Glossary: add "supremum (sup)", "Lipschitz constant (smallest)".

7. Figure 3 (Lipschitz cones): make an invalid bound visible, and explain that one K applies to all boxes. [Added by user]
   - Problem: the default K of 0.6 is far below the Lipschitz constant (about 5.9). The curve then goes below the V floors without any warning. Example: box [0, 1/3] has a floor near −0.28, and the curve dips to about −0.296 near x = 0.31. The box after 1/3 starts near −0.29 at its left edge, below its floor of about −0.21.
   - Draw the curve in a warning color wherever it falls below the V of its box. Add a readout: "K below the Lipschitz constant (≈ 5.9): bound violated in N boxes" or "bound valid in every box".
   - Caption: one K applies to every box. The V shapes differ in depth only because their dᵢ differ. Each V is the lower half of the Lipschitz hourglass (item 6) drawn from the box center. Only the lower half is drawn, because minimization needs a floor, not a ceiling.
   - Add a short note: local Lipschitz constants per region exist in other methods (Hansen, Jaumard and Lu [7], Sergeyev and Kvasov [8]). DIRECT gives no box its own K. Each potentially optimal box owns a range of K values (K₁ to K₂), the slopes of the hull edges next to its point in Figure 4.

8. Section 3, the paragraph on Piyavskii-Shubert and branch-and-bound: rewrite it as three explained parts. [Added by user]
   - Saw-tooth lower envelope: from each sample, draw the lower half of the hourglass (slope ±K). Between two neighbouring samples, the two falling lines cross and form a downward tooth. All teeth together make the lower envelope, a floor that f never goes below. Piyavskii-Shubert samples at the tip of the deepest tooth, then repeats. Say that Figure 3 uses DIRECT's box-centred version (one V per box), not the tooth-between-neighbours form. Consider a small diagram of the true saw-tooth.
   - Branch-and-bound as four named steps: branch (split into cells), bound (floor per cell, f(cᵢ) − K·dᵢ), select and refine (split the lowest-floor cell), and prune (discard for good any cell whose floor is above f_min). The old paragraph left out pruning. Analogy: rooms with a sign "nothing in here is lower than X". Open the lowest sign first, and lock the rooms whose sign is above the best height found.
   - Finite convergence to a tolerance: f* lies between the lowest floor and f_min, so the gap is a certificate (a proven error bound). Splits shrink cells by a factor of 3, so K·d → 0 and the gap closes. Stop when the gap is below the tolerance. Give the bracket as an equation with a "where" list.
   - State the link: DIRECT gives this up, because without a known K there are no valid floors and no certificate, hence the budget stop (section 6).
   - Notation fix: the old text uses ε for the tolerance, which clashes with DIRECT's ε in Eq. (4). Use τ for the tolerance everywhere it means "how close to f*", and add τ to the notation table.
   - Glossary: add "lower envelope", "pruning", "certificate (optimality gap)", "tolerance".

9. Section 3: show DIRECT's box-wise floor next to the Piyavskii-Shubert envelope. This extends the saw-tooth diagram of item 8. [Added by user]
   - Origin: the user drew red vertical lines that join the V of each box to the next at the box boundaries (screenshot of Figure 3 at K ≈ 2.3). Keep this as the "box-wise floor" view, and tag those step segments "added by user".
   - Box-wise floor (DIRECT): inside box i the floor is f(cᵢ) − K·|x − cᵢ|, from that box's own center only. The floor jumps at each boundary. Draw the jumps as vertical step segments in a distinct color, and say that no bound exists along them. Example at x = 1/3: about −0.55 just left (center 1/6) and about −0.29 just right.
   - The dashed horizontal line in each box is the bottom of its V, the box score f(cᵢ) − K·dᵢ. It is not part of the floor curve. Say this in the caption.
   - Piyavskii-Shubert envelope: every sample's cone covers the whole axis. At each x the envelope is the maximum over all samples of f(xᵢ) − K·|x − xᵢ|, which is continuous, with downward teeth whose tips sit where neighbouring cones cross. Give it as an equation with a "where" list, and explain "maximum" in words: each cone is a true statement "f is at least this here", and the highest one is the strongest.
   - Comparison point: at x = 1/3 the sample at about 0.389 is only 0.056 away, so the envelope is far higher than the box-wise floor of −0.55. The box-wise floor is valid but looser.
   - Why DIRECT accepts the looser floor: it needs one score per box, and the center gives it cheaply. DIRECT never builds an envelope. It only compares box scores over all K.
   - Interaction: a toggle with three states, "box-wise floor (DIRECT)", "Piyavskii-Shubert envelope" and "both", sharing the K slider of Figure 3 or of the new diagram. Apply the violation highlighting of item 7 to both views.
   - Glossary: add "upper envelope / pointwise maximum" next to "lower envelope". The lower bound is the pointwise maximum of the cones, so define the term to avoid confusion.

10. Figures 4 and 5: K is shared by all boxes, and DIRECT's selection is the full sweep of the K slider. [Added by user]
    - Origin: the user saw that the K slider moves the floors of all boxes together, and asked whether K moves separately for each box.
    - Add to the captions of Figure 4 and Figure 5: one trial K applies to every box at once, because the Lipschitz constant is a single property of the whole function. DIRECT asks "which box has the lowest floor for this K?" for every K > 0. That is the "for some K" of condition (3). The K is never set per box. What differs per box is the range K₁ to K₂ over which it wins.
    - Add a short paragraph in section 4, after the geometric interpretation: the sweep of the Figure 4 slider and the rotating line of Figure 6 are the same operation seen in two planes, the x-plane and the (d, f) plane.
    - Figure 4: add a "Sweep K" button. It animates K from 0 to the maximum, marks every box that has the lowest floor at some point of the sweep (keep the marks as the sweep goes on), and at the end shows the list of winners with their K ranges, K₁ to K₂. State in the readout that these are the boxes satisfying condition (3). Figure 6 removes some of them through condition (4) (ε). With ε = 10⁻⁴ the sets should match. Check this with the engine before publishing.
    - Respect prefers-reduced-motion: then the button jumps to the final state without animation.
    - Keep the contrast with methods that do use a K per region (Sergeyev and Kvasov local tuning [8]) in one sentence, and point to the existing paragraph in section 3.

11. Section 3, after Figure 4: make it obvious why only a few boxes can ever win, and why the others still matter. [Added by user]
    - Origin: the user asked why only 3 of the 9 rows in the Figure 4 table ever get highlighted, and whether the others play no role. The explanation below made it click ("ohhhhh okayyy"). The user asked to make it more obvious on the page.
    - Put the key statement in a "Core idea" box: boxes of the same size subtract the same K·d, so within a size group the box with the lowest center value wins for every K. The other boxes of that group are dominated. At most one box per size can ever win.
    - Make it visible in the Figure 4 table itself:
      - Group the rows by size dᵢ, with a light divider or a group label per size.
      - Add a column "can win for K in", showing K₁ to K₂ for the group winners and "never (dominated)" for the others.
      - Dim the dominated rows, and tag each with the box that dominates it.
    - Give the worked example from this exact partition (three sizes, so three candidates):
      - [0.889, 0.926] wins for K from 0 to 0.396 (exploitation),
      - [0.556, 0.667] wins from 0.396 to 0.805 (in between),
      - [0, 0.333] wins from 0.805 upwards (exploration).
      Show one switch point as a calculation: (−0.2561 + 0.2708) / (0.0556 − 0.0185) = 0.396. State that these switch points are the slopes of the hull edges in Figure 6. Compute every number with the engine before publishing, not from this note.
    - Dominance example: [0.778, 0.889] (−0.2500) and [0.556, 0.667] (−0.2561) have the same d. Their floors always differ by 0.0061, so the second always wins.
    - "Do the others play no role?", four points:
      1. They are never discarded, because DIRECT has no pruning step.
      2. They wait in a queue. Once the group winner is split, the next best box of that size can win, for example [0.778, 0.889].
      3. Their samples count towards f_min.
      4. Keeping them is what makes DIRECT globally convergent (section 9).
      Contrast with branch-and-bound, which knows K and can lock a room for good. DIRECT cannot prove that a box is hopeless, so it only puts the box at the back of the queue.
    - Link to item 10: the Sweep K button should visibly skip the dominated rows.
    - Glossary: add "dominated box".

12. Section 4: add a paragraph "Why the Lipschitz picture still matters". [Added by user]
    - Origin: the user asked how dropping the Lipschitz constant is useful, after spending time to understand it.
    - DIRECT drops only knowledge of the value of K, not the Lipschitz idea:
      1. Condition (3) compares exactly the Lipschitz floor f(cᵢ) − K·dᵢ.
      2. DIRECT assumes that f has some finite Lipschitz constant (the amplifier with an unknown slew rate).
      3. The convergence argument of section 9 uses the K → ∞ end of the sweep.
    - Key guarantee: let K* be the true constant. The box that Lipschitzian branch-and-bound with K* would split satisfies condition (3) for K = K*, so DIRECT always selects it. The only exception is a box that condition (4) removes because it cannot improve f_min by more than ε|f_min|. DIRECT gets the correct choice without knowing K. Its price is that it also splits the winners for every other K (global drag, section 11).
    - What DIRECT loses: the certificate (the gap between the lowest floor and f_min), which is why it stops on a budget.
    - Application note: a three-row comparison.
      - Classical Lipschitz optimization: known K, valid floors, a certificate.
      - DIRECT: unknown K, a sweep over all K, no certificate.
      - Ideas B and C: the measured PV current gives a valid ceiling on power over part of the curve, which restores a stopping test.
    - Check the guarantee statement carefully against Eqs. (3) and (4) before publishing. Ties are selected too, in the engine and in the original method.

13. Section 5: add a worked 1-D trace of how the Figure 4 partition was built. [Added by user]
    - Origin: the user asked how the windows are subdivided.
    - Give the 1-D rule in three steps: cut into thirds, reuse the old center as the center of the middle third, and evaluate the two outer centers (2 evaluations per split). Side lengths run 1, 1/3, 1/9, … and d = side/2 runs 0.1667, 0.0556, 0.0185, which are the three sizes of the Figure 4 table.
    - Add a table built from the engine, not from this note:
      - Start: [0, 1], center 0.5.
      - Iteration 1: split [0, 1] into [0, 1/3], [1/3, 2/3] and [2/3, 1].
      - Iteration 2: split [2/3, 1] (f = −0.25). The three boxes have equal size, so only the best center can win (dominance, item 11).
      - Iteration 3: split [1/3, 2/3] (best of the size-1/3 group, f = −0.21) and [8/9, 1] (best of the size-1/9 group, f = −0.253).
      - Evaluations: 1, 3, 5, 9.
    - Add a small interactive control (Prev/Next) or a static three-step strip that shows the partition after each iteration, with the split box highlighted. Reuse the existing engine.
    - Restate the n-D rule in four short steps next to Figure 7: longest sides, sample ±δ along each, keep the better value wₖ per side, and cut the best side first.

14. Section 4: simplify the explanation of "potentially optimal". No "Added by user" tag, because this rewrites existing text.
    - Before Eqs. (3) and (4), add a plain five-step walk-through:
      1. Score: for a chosen K, each box gets the score f(cᵢ) − K·dᵢ, its floor. Lower means more promising.
      2. The score depends on K. A small K ranks boxes by their center value (local). A large K ranks them by their size (global).
      3. K is unknown, so DIRECT ranks the boxes for every K and keeps each box that comes first at least once. "Potentially optimal" means "it could be the best box to split, if K happened to have the right value".
      4. Boxes of the same size compete only on their center value, so at most one box per size is in the running (link to item 11).
      5. A sanity filter (ε, Eq. 4): a winner must promise a real improvement over f_min, otherwise it is skipped. This mostly removes tiny boxes next to the best point.
    - Then give the formal Eqs. (3) and (4) as they stand.
    - Use the Figure 4 partition as the worked example: 9 boxes, 3 sizes, 3 winners with their K ranges (numbers from the engine).
    - Analogy: an interview shortlist when the weighting is unknown. Candidates have a test score (center value) and untested potential (box size). If you do not know how much to weight potential against score, you interview everyone who would rank first under some weighting. Nobody else can be the best hire under any weighting.
    - Keep the geometric picture (sliding line, lower-right hull) after the formal definition, as it is now.

15. Section 3 (where dᵢ is defined) and section 4 (where "size" is used): explain "box size" plainly. [Added by user]
    - Origin: the user asked "what is the box size?"
    - State that "size" always means the center-vertex distance dᵢ, half the diagonal of the box. Use the word consistently on the page, for example "size dᵢ".
    - Why this measure: the corners are the points farthest from the sampled center, so dᵢ is the largest distance over which f can drift from the known value. Under the speed limit K, the largest drop is K·dᵢ, which gives the floor f(cᵢ) − K·dᵢ. A larger dᵢ means more unexplored room in which a lower value could hide.
    - Formulas, as an equation with a "where" list: 1-D, d = half the interval length. n-D, d = ½·√(sum of the squared side lengths). 2-D, d = ½·√(a² + b²).
    - Example table: unit square 1 × 1 gives d ≈ 0.707. After one cut, 1/3 × 1 gives d ≈ 0.527. After both cuts, 1/3 × 1/3 gives d ≈ 0.236. In 1-D, [0, 1/3] gives d = 1/6 ≈ 0.1667 (Figure 4 table). Check the values numerically.
    - Side lengths are powers of 1/3, so only a limited set of d values occurs. This gives the vertical columns (size levels) in Figure 6.
    - Note from [2]: the variant DIRECT-l uses the infinity norm, which makes d half the longest side. The original DIRECT uses the Euclidean form.
    - Consider adding a small 2-D sketch: a rectangle, its center, the line from the center to one corner labelled dᵢ (like Fig. 5 in [2]).

16. Figure 6 (selection diagram): add a plain walk-through to the caption or just below it. [Added by user]
    - Origin: the user asked "what does figure 6 do, in simple terms?"
    - Dots: one per box. Horizontal position = size dᵢ (further right = more unexplored room). Vertical position = center value f(cᵢ) (lower = better). The promising boxes sit low or far right, on the bottom-right edge of the cloud.
    - Solid line: its slope is one trial K. Every point on it has the same floor f − K·d, and that floor is where the line crosses the left axis (d = 0). Slide the line up from below: the first dot it touches has the lowest floor for that K, the same box Figure 4 highlights at that K.
    - Animation: turning the line from flat to steep is the same as moving the Figure 4 K slider from 0 upwards. A flat line touches the lowest dot (local search). A steep line touches the rightmost dot (global search). The dots touched along the way are potentially optimal, and joined up they form the amber hull.
    - Columns: dots of equal size line up vertically, and only the bottom dot of a column can be touched (dominance, item 11).
    - Dashed line: the ε filter (item 17). It is anchored a little below f_min on the left axis and turned up until it hits a dot. Boxes left of that dot are skipped.
    - Closing sentence: Figure 4 asks "who wins at this K?" one K at a time. Figure 6 shows the answer for all K at once.

17. Section 4, after Eq. (4): explain ε plainly in its own subsection. [Added by user]
    - Origin: the user asked "what is epsilon?"
    - Definition: ε is DIRECT's only hyperparameter. It sets the smallest improvement worth chasing, as a fraction of the best value so far. Condition (4) in words: a box that wins for some K is split only if its floor promises a gain of at least ε·|f_min| over f_min, even under the most favourable K (the largest K for which it wins, K₂).
    - Worked example: f_min ≈ −0.296 and ε = 10⁻⁴ give a minimum gain of 0.0000296, so a box needs a floor of −0.29603 or lower. In words: gains below 0.01% are not chased. Compute the numbers with the engine.
    - Which boxes it removes: mostly the tiniest boxes next to the best point, because a small K·d gives a floor only a little below f_min. Big boxes pass easily. That is why the dashed line in Figure 6 cuts only the left end of the hull.
    - Evidence table from [2], Shubert function, evaluations to reach 0.01% accuracy: ε = 0 needs more than 10,000, ε = 10⁻⁷ needs 5,713, and ε = 10⁻⁴ needs 2,933.
    - Drawbacks: it slows the final refinement of the true global minimum. It also scales with |f_min|, so it almost vanishes when f_min ≈ 0 and changes when a constant is added to f. Link to the Finkel-Kelley fix in section 11.
    - Application note, MPPT: the margin is ε × the best power found. With a best power of 3,000 W and ε = 10⁻⁴, a box must promise at least 0.3 W more to be worth a settling period.
    - Disambiguation line: ε here is not τ (the tolerance to f*) and not the ε of ε-greedy (glossary).

18. Whole page, style: highlight key terms in bold and underlined. No user tag, because this is a style change.
    - At the defining use of each key technical term (each term that has a glossary entry, and each term in a "Core idea" box), use bold plus underline, for example a class .kt with font-weight 600 and text-decoration underline, in a theme-token color with text-underline-offset ≈ 0.18em.
    - Apply it to the terms the user asked about first: black-box, derivative-free, min-max normalization, Lipschitz constant, Lipschitz hourglass, lower envelope, branch-and-bound, pruning, certificate, potentially optimal, dominated box, box size (center-vertex distance), selection diagram, lower-right hull, ε, trisection, everywhere dense, global drag. Then apply it to the remaining glossary terms at their first defining use only. Later mentions stay plain.
    - Keep "Added by user" tags and links visually distinct from .kt, so that underlined terms are not mistaken for links. Use no link color and no hover effect on .kt.
    - Scope (user, 2026-11-21: "for the entire document"): apply this to the whole page, not only to section 4. That covers every numbered section, the "Core idea" boxes, the "where" lists, the figure captions, the notes, the notation table and the glossary (each glossary term in bold and underlined). Within the body, mark each key term at its first use in each section, so every section shows its key terms. Do not mark every repeat inside a section, because that clutters the text.

19. Whole page, style: make every "where" block stand out, so the reader does not miss it. No user tag, because this is a style change.
    - The word "where": bold and underlined (same .kt treatment as item 18), not italic and muted as now.
    - The block: give it its own light background tint and a thin left rule in the accent color, and place it directly under its equation, visually attached (small top margin, the same left edge as the .eq box), so equation and definitions read as one unit.
    - In each list item, set the symbol being defined in bold, so the reader can scan the symbols down the left side.
    - Apply this to every existing "where" block and to all new ones from items 1 to 17. Use theme tokens for both themes.

20. Whole page, math rendering: MathJax in place of the code-style equation blocks, with math larger than the text. No user tag, because this is a style change.
    - Replace every .eq block (the monospace, code-like boxes) with LaTeX display math rendered by MathJax 3. Keep the equation numbers with \tag{n}, for example \tag{2}.
    - Convert inline math to MathJax inline math (\( … \)) as well: the symbols in the body text, the "where" lists, the notation table, the glossary and the captions. One rendering for all math. The canvas labels inside figures stay as plain text, because MathJax cannot render into a canvas.
    - Loader: use the SVG output build, pinned, for example https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-svg.js (or the cdnjs copy of 3.2.2). Do not use the CHTML build: it fetches web-font files from the CDN, and the artifact CSP allows font files only from fonts.gstatic.com, so they would fail silently. Set the MathJax config object before the script tag: inlineMath \( \), displayMath \[ \], and svg fontCache 'global'.
    - Size: all math at least 2 pt larger than the body text. The body is 16 px (12 pt), so inline math is about 14 pt, scale ≈ 1.17. Display math is larger again, scale ≈ 1.25. Set this through the MathJax svg scale and a CSS rule on mjx-container (inline and display separately). Check that inline math does not push the line height apart badly.
    - Theme: SVG math uses currentColor, so it follows the text color in both themes. Display blocks keep a light token background (or none) and must scroll sideways inside their own container on phones (overflow-x: auto).
    - The "where" style of item 19 still applies under each display equation.
    - Fallback: if MathJax does not load, show the TeX source as plain text in the same place, not a blank gap.
    - Verify after the change: every equation renders, the numbers (1) to (4) are still right, there are no raw \( left in the text, and the page width holds at 400 px.

21. Figure 8 (live 1-D run): explain the strip and add the measured convergence. [Added by user]
    - Origin: the user asked what the yellow cells under the plot are, and whether the run finds the minimum in under 10 iterations.
    - Caption: the strip under the curve is the whole partition. Each cell is one interval (a 1-D hyperrectangle), and the ticks are its boundaries. The yellow cells are the potentially optimal intervals, the set S that the next Step will split. They are the same boxes as the yellow dots in the right panel, and "|S| next" in the stats line counts them.
    - Add a paragraph and a table under the figure, "How fast does it find the minimum?". Generate it with the engine at build time, not from this note. Values measured on 2026-11-21, f* = −0.2964:
      - Within 1%: iteration 5, 17 evaluations, for both ε.
      - Within 0.1%: iteration 7, 27 evaluations, for both ε.
      - Within 0.01%: iteration 9, 37 evaluations (ε = 0.01), and iteration 8, 33 evaluations (ε = 10⁻⁴).
      - Evaluations by iteration 23: 99 (ε = 0.01) and 163 (ε = 10⁻⁴).
    - Three caveats:
      1. Count evaluations, not iterations. One iteration splits several boxes at 2 evaluations each. For MPPT, one evaluation is one settling period.
      2. DIRECT does not know it has found the minimum (no certificate). It keeps splitting boxes all over the axis, which is the dense sampling of section 9 and the global drag of section 11. A real controller must stop on a budget.
      3. ε in action: both settings find the minimum at about the same time, but a larger ε wastes fewer evaluations polishing it (99 against 163 by iteration 23). Link to item 17.
    - State that this test curve is easy (one variable, three valleys). The examples in [2] need hundreds to thousands of evaluations.
    - Optional: show in the stats line the iteration at which f_min first came within 1%, 0.1% and 0.01% of f*, so the reader sees it happen live.

22. Mark the 2-D material as general background, and state what simplifies in 1-D. [Added by user]
    - Origin: the user asked whether anything 2-D is needed. For the project it is not: MPPT with one converter has one decision variable (the duty cycle), so DIRECT runs in 1-D.
    - Add a small marker label, for example "General n-D background, not needed for 1-D MPPT", at: the n-D division rule and Figure 7 (section 5), the n-D size formula and the 2-D example table (item 15), Figure 9 (3-D view, section 8), and the dimension weakness §2.3.4 (section 11). Use one consistent label style, distinct from "Added by user".
    - Add one application note "1-D is enough for MPPT", in section 5 or 12, listing what simplifies:
      - d is half the interval length.
      - The division rule has no choice to make: one side only, so the wₖ ordering step disappears and every split is a plain trisection.
      - The curse of dimensionality (§2.3.4) does not apply.
    - Keep the 2-D parts. They support the paper's numbers (Branin, Shubert, linear examples), and Figure 9 shows the clustering clearly.

----
Items 10 to 22 were applied and published on 2026-11-21 (artifact version 5). See Notes/DIRECT_EXPLAINER_LOG.md, LOG-006.

23. PAGE 2 (requested 2026-11-21). DONE in v9 on 2026-11-21, see LOG-011. Published as ideas.html in the same artifact.
    - A second page of the artifact: explain Ideas B and C and how they modify DIRECT.
    - Order the user asked for:
      1. the actual prior DIRECT implementations on MPPT,
      2. what we borrow from them,
      3. what they missed,
      4. what our ideas potentially add, and how unique or bespoke that is compared with them.
    - Constraints: no novelty claims (CLAUDE.md rule 3, Notes/novelty_check_ideas_B_C.md section 7). Ideas B and C are implementations of published parts, so cite every part. Sources: HANDOFF_ideas_B_C.md, Notes/direct_literature_and_ideas.md, Notes/idea_B_theory_and_baselines.md, Notes/thesis_text_B_C.md, Reference_Papers. Apply the same style as page 1 (MathJax, key terms, where blocks, user tags).

24. Page 1, Figure 4, Sweep K: make the sweep show where the winner changes. APPLIED in v10 (LOG-012).
    - Origin: the user asked whether Sweep K was broken (2026-11-21). The logic is correct, see LOG-010. The reduce-motion part is already fixed in v8.
    - Problem: all switch points are below K = 0.805 (at 0.395 and 0.805), but the sweep runs to K = 14. So the change takes about 0.25 s, and the other 4 s show nothing new.
    - Proposal: sweep slowly over K = 0 to 1.2, pause at each switch point, and print a line such as "K = 0.395: the lowest floor moves from [0.889, 0.926] to [0.556, 0.667]". Then jump to the end.

25. Page 2: add a plain-language "The ideas at a glance" section near the top, before section 2. [Added by user] APPLIED in v10 (LOG-012).
    - Origin: the user asked (2026-11-21) to put the chat description of the ideas on the page, because only the user and Claude know them. Teammates who read the page need this summary before the detailed sections.
    - Content, in plain steps, one short block for each:
      1. Nguyen and Low (2010), the tracker that the project starts from:
         - Trisect the duty range and sample the centres. Run the shading test.
         - Run a few cycles that favour large intervals. Skip rules that use Voc and Isc drop some intervals.
         - Hand over to P&O when the two best samples are neighbours. This rule is a rule of thumb. At the hand-over, the samples cannot exclude a hill with up to 37 % more power than the best one (Cert up to 1.369). DIRECT finds the global peak in 90 to 97 % of the 1800 random cases.
      2. The measured ceiling, in three lines: a higher duty gives a lower voltage, so V ≤ V₁ in the gap. The current never rises with the voltage, so I ≤ I₂ in the gap. So P ≤ V₁·I₂ in the gap, with no constant, datasheet value or model. Source of the inequality: Boztepe 2014, Wang 2016. State that the physics takes the place of the Lipschitz constant K of page 1.
      3. Idea A: the ceiling used inside DIRECT to prune intervals. It saved 0.1 probes, because early DIRECT samples are far apart and their ceilings are loose. Dropped.
      4. Idea B: run DIRECT as published, then check the gaps before the hand-over. A gap is open if its ceiling exceeds 1.02 × P_best and it is wider than 0.01 in duty. Sample the open gap with the highest ceiling. Repeat until no gap is open.
      5. Idea B refined: drop the DIRECT stages that the check makes redundant, and split each gap at its corner duty (the load line through (V₁, I₂)). The split is the projection step of the polyblock algorithm, so it is not new.
      6. Idea C: no DIRECT. Start from D = 0.30, 0.54 and 0.78 and run the same check from the start. Each split halves a gap and costs one probe. It is a Piyavskii-Shubert-type search, as LIPO is, with the measured ceiling in place of the Lipschitz bound.
      7. How distinct: every part exists, and monotonic optimization has the whole structure in general form. No GMPPT paper that the project found applies it. No novelty claim.
    - Stop conditions, as a short list in the same section (section 9 keeps the full version):
      1. Certificate stop: every gap wider than τ = 0.01 has V₁·I₂ ≤ 1.02 × P_best. The tracker can then state P* ≤ max(1.02 × P_best, the ceilings of the narrow gaps).
      2. Sample cap: 64 samples (fixed arrays for code generation). If full, the search ends at the best sample. Worst case about 96 gaps on a flat curve. The 1800 cases needed 24 probes at most.
      3. Hand-over and restart: P&O holds the peak and never stops. A new search starts on a power change above 5 % from the hand-over value, or on the optional timer (off by default). Largest P&O change in the project runs: 1.55 %, so no false restart.
    - Form: a compact table or a numbered list with one line for each idea, plus the three stop layers. Link each block to its detailed section (2.1, 5, 6, 7, 7.1, 8, 9). Put the "Added by user" tag on the section heading.

26. Page 2: add a comparison "Idea B or Idea C: which is more robust?" [Added by user] APPLIED in v11 (LOG-013), as section 24.3.
    - Origin: the user asked (2026-11-21) whether B or C is more robust in the long run.
    - Place: section 10, as a new subsection 10.3, after "How distinct is this?". Add one line and a link in "The ideas at a glance".
    - Answer first: by the guarantee they are equal. By long-run exposure, C is more robust because it has fewer parts that can drift. B refined is faster. The measured difference is small.
    - Where they are equal:
      - The same stop test and the same four assumptions (monotone current, monotone converter map, steady-state samples, fixed curve during the search). When an assumption fails, both are exposed in the same way.
      - A wrong decision of the DIRECT stage of B (shading test or skip rule) costs probes, not correctness, because the check computes a ceiling for every gap between samples, also the gaps that DIRECT skipped.
      - Results table, 1800 static cases (three shading types, with and without 0.5 % noise):
        | Method | GMPP found | Worst case | Mean probes |
        | Idea B | 99.7 to 100 % | 97.5 % | 13.6 to 15.5 |
        | Idea B refined | 99.9 to 100 % | 98.0 % | 11.7 to 13.9 |
        | Idea C | 99.7 to 100 % | 97.9 % | 12.8 to 14.3 |
        In Simulink, all three reach the GMPP on all nine patterns.
    - Why C is more robust in the long run:
      - Fewer settings: C has eps_c and tau only. B adds the shading thresholds of DIRECT, the skip rules with Voc and Isc at STC, and the local spacing. Real Voc and Isc drift with temperature, ageing and soiling. Then the DIRECT stage of B spends its probes less well. It stays correct but becomes slower.
      - Less sensitive to tau: with tau = 0.02, Idea B missed 2 of 900 cases. Idea C missed none at any tested setting, and its worst case fell to 98.2 % (Notes/gmppt_m1_m4_comparative_study.md, section 12.2).
      - Simpler code: fewer phases, fewer branches, one path to the hand-over.
      - Portable: C needs no array values. B needs the Voc and Isc of the new array.
    - Where B refined is better:
      - Speed: it hands over first, 8 to 14 probes, 0.38 to 0.62 s in Simulink. So it gives a little more energy in the first second after each restart.
      - Noise: with 0.5 % noise it finds the GMPP in 99.9 % of 900 cases (Idea B: 99.4 %). Before writing this on the page, get the matching single figure for C from the cross-check results, so that the comparison is like for like.
      - Caveat on the corner split: it uses the measured V and I to choose the next duty, so measurement error moves the probes. In Simulink this changed the order of two probes on R2 and R4, but the probe count and the hand-over stayed the same. The midpoint split of C does not depend on the measurements.
    - State the limit plainly: "long run" here is reasoning, not data. The project has no test of ageing, temperature drift or hardware. The page must call the long-run argument a hypothesis.
    - Close with the recommendation: C where robustness and simplicity matter most, B refined where the speed after each restart matters most. The thesis can report both.
