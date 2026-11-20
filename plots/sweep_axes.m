function [Vax, Pax, Iax] = sweep_axes(res, cfg)
%SWEEP_AXES Axis ends for the sweep figures, from the data, so that they fit any panel.
%   res is the struct array of results/pv4x4_sweeps.mat. res(1) is P0.
Vax = 10 * ceil(1.05 * cfg.arr.Voc / 10);         % End of the voltage axis [V]
Pax = 500 * ceil(1.15 * res(1).gmpp(2) / 500);    % End of the power axis [W]
Iax = 5 * ceil(1.1 * cfg.arr.Isc / 5);            % End of the current axis [A]
end
