# DIRECT_EXPLAINER_LOG: decision log of the DIRECT explainer page

Append-only. Never delete an entry. If a decision is reversed, add a new entry that replaces it and names the old one. One entry for each significant change.

- Page: https://claude.ai/artifact/AakEZgGYpjPyAY8745wC5P (private artifact)
- Source copies: `Notes/DIRECT_explainer/direct_explainer.html` (page 1, served as index.html) and `Notes/DIRECT_explainer/ideas.html` (page 2)
- Change list: `Notes/DIRECT_explainer/pending_edits.md` (items 1 to 23)
- Main source: Jones and Martins, "The DIRECT algorithm: 25 years later", J. Glob. Optim. 79 (2021) 521-566. Local copy: `Literature/jones2021direct25_author.pdf`.

---

**LOG-001 · 2026-11-20 · Version 1: first explainer.** The user asked for an explanation of DIRECT from first principles, based on Jones and Martins (2021), with three.js visuals and no project code. The page used plain language and an MPPT framing. It has a DIRECT engine in JavaScript (Algorithms 1 and 2 of the paper), and every figure uses that engine. A Node run checked the engine before publishing. Fix found in that check: the steepest slope of the test curve is about 5.9, not 12.

**LOG-002 · 2026-11-20 · Version 2: lecture-note rewrite (replaces the style of LOG-001).** The user said that the page did not use proper engineering terms and asked for a professor-style explanation. The rewrite uses conventional optimization terms. Each section gives the core idea, then the formal statement, then an analogy. The analogies come from the user's background: the sampling theorem, slew rate, bisection, finite-element mesh refinement, the lower confidence bound and epsilon-greedy exploration. The rewrite added 13 numbered IEEE-style references. Most of them come from the reference list of the paper. The solar framing moved to one application note, because the user asked for a general treatment. Memory: `explain-like-a-professor`.

**LOG-003 · 2026-11-20 · Version 3: symbols and terms defined separately.** The user asked for a definition of every variable and term. Version 3 added a notation table (section 0), a "where" list under each equation, and a glossary appendix with 40 terms. The check found that the paper uses m for two quantities. The page states that both counts are equal.

**LOG-004 · 2026-11-20 · Reading workflow and chat math.** The user started to read the page and to ask questions. The agreed workflow: keep a running list of changes, and apply the list only when the user asks. Each change that comes from a user question carries an "Added by user" tag on the page. The user said that the chat math did not render. The first reading of that complaint was wrong: chat was not the place to drop math, and the artifact did not need KaTeX. The user corrected it. The chat view shows HTML tags such as `<sub>` as raw text, so chat now uses Unicode symbols only. Memory: `math-in-artifacts-not-chat`.

**LOG-005 · 2026-11-21 · Version 4: items 1 to 9 applied.** These items came from the user's questions on sections 1 to 3:
1. Min-max normalization, with its formula, its inverse, the caution about bounds, and why DIRECT needs it.
2. Derivative-free optimization: roles, three reasons, the finite-difference cost, method families, and the "direct search" name clash.
3. What "expensive" refers to, and the overhead of DIRECT itself.
4. Three clarifications of the dense-sampling proof, plus the Lipschitz spacing result 2τ/K.
5. DIRECT builds no model of f, compared with surrogate methods (EGO).
6. The Lipschitz hourglass, with a new interactive figure.
7. The violation highlight in the cone figure. At the default K = 0.6, four boxes break the bound.
8. Piyavskii-Shubert, branch-and-bound with pruning, and the certificate.
9. A new figure that compares the box-wise floor of DIRECT with the Piyavskii-Shubert envelope. The user's red step lines appear in it with credit.

Notation fix: the tolerance is now τ, so it does not clash with the ε of DIRECT. Fix: a caption pointed global drag to section 10. It now points to section 11.

**LOG-006 · 2026-11-21 · Version 5: items 10 to 22 applied, plus a new math and term style.** These items came from questions on sections 3 to 7:
- 10. One trial K applies to all boxes. A "Sweep K" button shows that the sweep gives the selection of DIRECT. A Node check confirmed that the sweep winners are the selected set (centers 0.167, 0.611 and 0.907).
- 11. Dominated boxes. The Figure 4 table now groups boxes by size, shows the K range of each winner, and dims the dominated rows.
- 12. Why the Lipschitz picture still matters. The page now states a guarantee: DIRECT always selects the box that a method with the true K would split. It skips that box only when f_min is already within the relative accuracy ε. The page also has a three-row comparison that leads to Ideas B and C.
- 13. A trace of how the partition was built, as a new Figure 7 with a table that the engine computes.
- 14. A simpler five-step explanation of "potentially optimal", with an interview-shortlist analogy. This item has no user tag, because it rewrites existing text.
- 15. Box size: the center-vertex distance, its formula, its examples, a small sketch, and DIRECT-l.
- 16. A plain walk-through of Figure 6.
- 17. What ε does: the worked example, the evidence from the Shubert function, the drawbacks, and the 0.3 W MPPT example.
- 18. Key terms in bold and underlined across the whole page (118 marks).
- 19. "Where" blocks stand out: a tinted panel joined to the equation, the word "where" in bold, and each symbol in bold.
- 20. MathJax 3 (SVG build, pinned 3.2.2) for all math, display and inline. Inline math is set at 1.17 times the body size, about 14 pt against 12 pt. Display math is larger again. The SVG build was chosen because the artifact policy blocks the font files of the CHTML build.
- 21. The figure strip and a "How fast does it find the minimum?" table, computed by the engine. The figure also shows live milestones.
- 22. A "1-D is enough for MPPT" note and "n-D background" labels on the 2-D material.

Renumbered figures: the new partition trace is Figure 7. The old Figures 7, 8 and 9 are now 8, 9 and 10. Fix: in chat, the ε example gave a threshold of −0.29603. The correct value for f_min ≈ −0.2964 is about −0.29643, and the page uses the correct value. Checks before publishing: script syntax, 587 inline and 14 display math spans balanced, no em dashes or semicolons in the prose, and figure references 1 to 10 present. The page source and the change list now have copies in `Notes/DIRECT_explainer/`, because the session scratchpad can be cleared.

**LOG-007 · 2026-11-21 · Page 2 requested and on hold.** The user asked for a second page about Ideas B and C. It must cover, in this order: the prior DIRECT implementations on MPPT, what we borrow from them, what they missed, and what our ideas add and how bespoke that is. The user then said to stop and wait. Nothing is built. Item 23 in the change list holds the request and its limits: no novelty claims, a citation for every borrowed part, and the same style as page 1.

**LOG-008 · 2026-11-21 · Version 6: math size fix and a wider page (replaces the math size of LOG-006, item 20).** The user found the math in version 5 "huuuge" and broken. Cause 1: the CSS rule `.fig svg{width:100%}` was for the figure drawings, but it also stretched each MathJax SVG in the figure captions to the full figure width. The rule now excludes the SVG of MathJax. Cause 2: the inline scale of 1.17 was too large, because MathJax already matches the x-height of the Inter body font, and Inter has a tall x-height. The scale is now 1, and display math is at 100 %. Cause 3: the symbols in the "where" lists used `\boldsymbol`, which made them heavy. All 55 `\boldsymbol` wrappers are removed. The "where" label keeps its bold and underline. The text column is now 84ch wide (was 68ch), and the page frame is 1240 px (was 1040 px).

**LOG-009 · 2026-11-21 · Version 7: figure width restored (replaces the frame width of LOG-008).** The user wanted the figures at their old size. The page frame, which sets the figure width, is 1040 px again. The text column stays at 84ch.

**LOG-010 · 2026-11-21 · Version 8: animations ignore the reduce-motion setting.** The user asked whether the Sweep K button of Figure 4 was broken. A headless Edge test showed that the sweep logic is correct: it ticks 3 boxes, which is the set that DIRECT selects. Two causes made it look broken. First, the user has the operating-system "reduce motion" setting on, and the page then skipped the animation and jumped K to 14. Second, all switch points are below K = 0.805 (at 0.395 and 0.805), but the sweep runs to 14, so most of the 4.4 s shows no change. On request of the user, the page now ignores the reduce-motion setting everywhere: the Sweep K animation, the autoplay of Figure 5, the step timer of Figure 9 and the autoplay of the 3-D figure. The second cause is proposed as item 24 (a slow sweep over 0 to 1.2 with a pause and a readout at each switch point) and is not applied.

**LOG-011 · 2026-11-21 · Version 9: page 2 built (closes LOG-007, item 23).** Page 2 is the published file `ideas.html` of the same artifact. Page 1 links to it at the top and at the end, and page 2 links back to `index.html`. The sections follow the order that the user asked for: prior DIRECT trackers on MPPT (Nguyen and Low 2010, and the close relatives Boztepe, Wang, Khong, LIPO, PRISM and Tiong), the borrowed parts with a source for each, what the prior trackers leave open, the measured ceiling with its lemma and proof, Idea A, Idea B and Idea B refined, Idea C, the stop rules, the results, and a table of how distinct the ideas are. The user asked two questions during the build. "Do the ideas have a plan on how to stop?" became section 9 (certificate stop, 64-sample cap, P&O hand-over and restart triggers, and a comparison with the stop rules of the other trackers). "What was Idea A?" became section 6. Both carry the "Added by user" tag. Figure 1 shows the ceiling box on an I-V curve. Figure 2 runs Idea C step by step, with a midpoint or a corner split. Both figures use a model string of three bypass groups, not the 4 × 4 project array, and the page says so. A headless Edge test ran Figure 2 on the three shading cases with both split rules. Each run stopped with the certificate, at 99.92 to 99.99 % of the true maximum, in 9 to 16 probes. The test found one false caption claim: with an ε_c of 0.05, the search still found the right hill. The caption now says that the stop is weaker but the result was correct on that curve. All numbers come from `Notes/novelty_check_ideas_B_C.md`, `Notes/idea_B_theory_and_baselines.md`, `Notes/gmppt_B_C_simulink.md` and `HANDOFF_ideas_B_C.md`. The page makes no novelty claim, and it uses the wording of section 7.1 of the novelty check.

**LOG-012 · 2026-11-21 · Version 10: items 24 and 25 applied, and two page-2 faults fixed.**
- Item 24 (page 1, Figure 4). Sweep K now runs over K = 0 to 1.2 in steps of 0.01. It pauses at each switch point and writes a line under the figure, for example "K = 0.395: the lowest floor moves from [0.889, 0.926] to [0.556, 0.667]". It ends with a note that the largest box wins for every larger K. The slider step is now 0.005, so the slider shows the switch values. A headless Edge test found the switch points 0.395 and 0.805 and the same 3 boxes as the selection of DIRECT.
- Item 25 (page 2). A new section "The ideas at a glance" after section 1, with the "Added by user" tag. It has the tracker of Nguyen and Low in three steps, the measured ceiling in three lines, a table of Ideas A, B, B refined and C, the three stop layers, and one paragraph on how distinct the ideas are. Each block links to its detailed section.
- Fault 1 (in version 9). Five equations on page 2 had a raw "<" (for example \(d_1<d_2\)). The browser read it as the start of a tag and hid the text after it. The equations now use \lt. Page 1 had no such case. The checks of LOG-006 tested page 1 only.
- Fault 2 (found before publishing). The new section anchors used the id "s2", which the stats line of Figure 2 also used. The figure script then wrote over section 2. The anchors now use the prefix "sec".
- The user asked for a stop rule for DIRECT from the peak count and from a best power that stops changing. That discussion is open and is not in the change list, at the request of the user.

**LOG-013 · 2026-11-21 · Version 11: the two pages become one document, item 26 applied, long blocks split.**
- Request of the user: make the notes of both pages read as one contiguous document, break up the large paragraphs and the long figure captions, and apply all pending items.
- Numbering. Page 1 is "part 1 of 2" (sections 0 to 12, Figures 1 to 10, references [1] to [17]). Page 2 is "part 2 of 2" and continues the numbers: sections 13 to 24, Figures 11 and 12, references [18] to [34]. Sources that both pages cite (Jones et al. 1993, Jones and Martins 2021, Piyavskii, Shubert, Sergeyev and Kvasov 2006) now use their part-1 numbers on page 2. Part 2 refers to part 1 sections by number, for example "section 9", in place of "page 1, section 7". That old reference was also wrong: convergence is section 9.
- Links. Each page links to the other at the top and at the end. Part 1, section 12 now points forward to part 2.
- Long blocks. 25 paragraphs and captions over about 420 characters were split at sentence boundaries, without a change to the words. Long captions now have short labelled parts, such as "Controls", "Reading the plot", "Table", "Try it" and "Legend". The lede of each page has a short list.
- Item 26. New section 24.3, "Idea B or Idea C: which is more robust?", and one paragraph "Which idea to choose" in section 15. The noise column uses the 900-case ablation of `crosscheck/results_ideab_refined.md`: Idea B 99.4 %, Idea B refined 99.9 %, Idea C 99.7 % (Idea C with the corner split 99.9 %, static study only).
- Checks. Balanced math, no raw "<" in math, no duplicate ids, no em dash. A headless Edge test ran both pages: no script error, all in-page links resolve, Figure 12 stops with the certificate, and Sweep K finds the switch points 0.395 and 0.805. One renumbering error was found and fixed before publishing ("Section 9 showed" had become "Section 23 showed").
- Backups of version 10: `direct_explainer_v10_backup.html` and `p2/ideas_v10_backup.html` in the session scratchpad.
