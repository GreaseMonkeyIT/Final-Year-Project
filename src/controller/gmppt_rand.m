function [s, r] = gmppt_rand(s)
%GMPPT_RAND One random number from a linear congruential generator.
%
%   [s, r] = gmppt_rand(s) moves the generator state s one step and
%   returns a number r in the open interval (0, 1). PSO and GWO use this
%   function in place of rand, so that every run repeats and Simulink
%   Coder needs no random number library.
%
%   Generator: s = mod(16807 * s, 2^31 - 1), r = s / (2^31 - 1). This is
%   the "minimal standard" generator of S. K. Park and K. W. Miller,
%   "Random number generators: good ones are hard to find," Commun. ACM,
%   vol. 31, no. 10, pp. 1192-1201, 1988. The product 16807 * s is below
%   2^53, so double arithmetic gives the exact integer.
%
%   The start value is p.rng_seed, an integer from 1 to 2^31 - 2. The
%   state never becomes 0.

m = 2147483647;                % 2^31 - 1
s = mod(16807 * s, m);
r = s / m;
end
