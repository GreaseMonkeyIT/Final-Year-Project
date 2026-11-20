# Abstract

**Implementation of MPPT for PV Arrays under Partial Shading Conditions**

A photovoltaic array under uniform light has one maximum power point. Under partial shade it has several. Bypass diodes cut the power-voltage curve into a staircase with one peak for each bypass group. Classical trackers such as perturb and observe climb to the nearest peak and stop. The array then delivers part of the power that it can produce.

Published work answers this with metaheuristic search. Ahessab, Gaga and Elhadadi (2024) seed a particle swarm with an artificial neural network. They report tracking efficiency near 100 percent on an eight-module array with a DSP F28379D controller. Their search settles in 0.1 s in simulation, but it needs 10 s to 15 s on the bench. The controller must apply each candidate voltage and wait for the power stage to settle. Settling time, not arithmetic, sets the cost of a search.

This project makes the number of applied operating points the design objective. It rebuilds the array, the boost converter and the three shading cases of that study in MATLAB-Simulink. The array model uses five parameters fitted to the datasheet points of the module. It implements perturb and observe, particle swarm and the neural-network-seeded hybrid as baselines. Against these it sets a deterministic tracker.

The number of series bypass groups limits the count of peaks. Each peak lies near a known multiple of the module open-circuit voltage. The tracker probes those windows, selects the best one, and refines it with a golden-section line search. The cost is 2Nm + 7 applied points for Nm bypass groups, with no random numbers and no tuning constants.

A boost converter and a TI C2000 controller carry the method to hardware. Four measures score every tracker: applied operating points, tracking time, tracking efficiency and steady-state oscillation. The expected result is the true global peak in about 15 applied points for a four-module string. Particle swarm needs roughly 90.

**Keywords:** photovoltaic array, maximum power point tracking, partial shading, global maximum power point, bypass diode, golden-section search, particle swarm optimization, boost converter.

---

## Short form (about 150 words)

A photovoltaic array under partial shade has several local maximum power points and one global peak. Perturb and observe climbs to the nearest peak and stops, so the array loses power. Published solutions apply metaheuristic search. Ahessab, Gaga and Elhadadi (2024) seed a particle swarm with a neural network. Their tracker reaches the global peak in 0.1 s in simulation. On hardware it needs 10 s to 15 s. The gap shows the real cost: the controller must apply each candidate voltage and wait for it to settle.

This project counts applied operating points instead of arithmetic. It reproduces the array, converter and shading cases of that study in MATLAB-Simulink, then adds a deterministic tracker. Bypass diodes fix both the number of peaks and their approximate voltages. The tracker probes one window for each peak and refines the winner with a golden-section search. A boost converter and a TI C2000 controller carry the method to hardware.
