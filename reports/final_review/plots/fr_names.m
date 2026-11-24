function name = fr_names(alg)
%FR_NAMES Name of a search for the phases that store only p.alg (p1b, p1c, p5).
%   In the third run (2026-11-23) DIRECT runs as in its paper.
n = {'P&O from start-up', 'INC from start-up', 'DIRECT (paper)', 'Idea B + Parabolic', ...
     'Idea C + Parabolic', 'PSO + Parabolic', 'GWO + Parabolic'};
name = n{alg};
end
