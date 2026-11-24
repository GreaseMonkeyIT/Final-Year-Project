function s = sens_draw(s, seed)
%SENS_DRAW Sensor and ADC values of one run, with random static errors.
%
%   s = sens_draw(s, seed) takes cfg.sens of pv4x4_config.m and returns a
%   copy with s.on = 1, s.seed = seed and new static errors. Each static
%   error (gain and offset of both sensor paths, ADC gain, offset and INL)
%   is uniform between minus and plus its typical value in cfg.sens. The
%   noise values do not change. Two runs with the same seed get the same
%   errors and the same noise.

rs = RandStream('mt19937ar', 'Seed', seed);
u  = @() 2 * rand(rs) - 1;
s.on   = 1;
s.seed = seed;
s.eV = s.eV * u(); s.oV = s.oV * u();
s.eI = s.eI * u(); s.oI = s.oI * u();
s.adc_gain = s.adc_gain * u(); s.adc_off = s.adc_off * u(); s.adc_inl = s.adc_inl * u();
end
