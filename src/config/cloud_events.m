function ev = cloud_events(fit, nEv, seed, Tw, dt)
%CLOUD_EVENTS Cloud-edge events on the 4 x 4 array, drawn from the Oahu fit.
%
%   ev = cloud_events(fit, nEv, seed, Tw, dt) returns nEv events. fit is
%   the struct of results/oahu_fit.mat (experiments/oahu_fit.m). Each
%   event is a straight cloud edge that crosses the array. Defaults:
%   Tw = [] (a window for each event, see below), dt = 0.01 s (time step of G).
%
%   Edge model. The edge moves with the speed v in the direction u (unit
%   vector). At a point r and a time t, the distance of the point ahead of
%   the edge is xi = r.u - v*(t - tc). The clear-sky index is
%     kt = kLow + (kHigh - kLow) * 0.5*(1 + tanh(+/-xi / sigma))
%   with sigma = w / 2.197, so that w is the 10 % to 90 % width of the
%   edge. The sign gives an edge that brings the shade (+) or the light
%   (-). The irradiance is G = Gclr * kt.
%   Values of each event, drawn from the fit (each value from its own
%   distribution, as independent draws):
%     v      speed [m/s]               from fit.spd
%     u      direction of motion       from fit.dir
%     w      edge width [m]            from fit.width
%     kLow   kt in the shade           from fit.low (falling edges)
%     kHigh  kt in the light           from fit.up
%     sense  shade arrives or leaves   0.5 each
%     Gclr   clear-sky irradiance      uniform from 800 to 1000 W/m^2
%   With Tw = [], each event gets its own window: 4 s before the edge
%   reaches the array, the time of the crossing (twice the edge width
%   plus the length of the array along u, over v), and 2 s after, at
%   least 10 s and at most 40 s. With a number Tw, the middle of the edge
%   crosses the middle of the array at 0.6 Tw.
%
%   Geometry (assumed). Panels in landscape, 1.96 m x 0.99 m, strings
%   side by side: the array is 7.84 m wide (x) and 3.96 m high (y). The
%   three bypass groups of a panel are strips of 1.96 m x 0.33 m, top to
%   bottom, as the rows of shading_patterns_grp.m. The plane of the array
%   is taken as horizontal. The irradiance of a group is the mean over
%   5 points along its strip.
%
%   Fields of each event: v, dir, w, kLow, kHigh, sense, Gclr, t (column,
%   0 to Tw), G (numel(t) x 48, rows of G(:)' of a 12 x 4 group matrix).

if nargin < 4, Tw = []; end
if nargin < 5, dt = 0.01; end
rs = RandStream('mt19937ar', 'Seed', seed);
pick = @(v) v(randi(rs, numel(v)));
% Group centres and sample points.
[gx, gy] = deal(zeros(12, 4, 5));
for c = 1:4
    for q = 1:12
        xs = (c - 1) * 1.96 + linspace(0.196, 1.764, 5);
        gx(q, c, :) = xs;
        gy(q, c, :) = 3.96 - (q - 0.5) * 0.33;
    end
end
x0 = 7.84 / 2; y0 = 3.96 / 2;
lows = fit.low(fit.amp < 0);
ev = struct('v', {}, 'dir', {}, 'w', {}, 'kLow', {}, 'kHigh', {}, 'sense', {}, 'Gclr', {}, 't', {}, 'G', {});
for k = 1:nEv
    v = pick(fit.spd); th = pick(fit.dir); w = max(pick(fit.width), 0.5);
    kL = pick(lows); kH = max(pick(fit.up), kL + 0.3);
    sense = 1 - 2 * (rand(rs) < 0.5);       % +1: shade arrives, -1: light arrives
    Gc = 800 + 200 * rand(rs);
    u = [sind(th) cosd(th)];                % Direction of motion (east, north)
    if isempty(Tw)
        % Window of this event: 4 s before the edge reaches the array, the
        % crossing (edge width plus the length of the array along u), 2 s
        % after. At least 10 s, at most 40 s.
        tx  = (2 * w + 7.84 * abs(u(1)) + 3.96 * abs(u(2))) / v;
        tc  = 4 + 0.5 * tx;
        Twk = min(max(tc + 0.5 * tx + 2, 10), 40);
    else
        tc = 0.6 * Tw; Twk = Tw;
    end
    t  = (0:dt:Twk)';
    sg = w / 2.197;
    G = zeros(numel(t), 48);
    for j = 1:numel(t)
        xi = ((gx - x0) * u(1) + (gy - y0) * u(2)) - v * (t(j) - tc);
        kt = kL + (kH - kL) * 0.5 * (1 + tanh(sense * xi / sg));
        g  = Gc * mean(kt, 3);              % 12 x 4
        G(j, :) = g(:)';
    end
    ev(k) = struct('v', v, 'dir', th, 'w', w, 'kLow', kL, 'kHigh', kH, 'sense', sense, 'Gclr', Gc, 't', t, 'G', G);
end
end
