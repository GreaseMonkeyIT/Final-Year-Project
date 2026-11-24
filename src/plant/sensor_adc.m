function [Vm, Im] = sensor_adc(V, I, w, s)
%SENSOR_ADC Measured voltage and current after the sensors and the ADC.
%
%   [Vm, Im] = sensor_adc(V, I, w, s) returns the values that the
%   controller reads for the true array voltage V [V] and current I [A].
%   w holds four samples of a standard normal noise: [sensor V, sensor I,
%   ADC V, ADC I]. s is cfg.sens of pv4x4_config.m. With s.on = 0 the
%   function returns V and I.
%
%   Each channel:
%     x    = k*u*(1 + e) + o + n*w1          voltage at the ADC pin [V]
%     c    = x/LSB*(1 + gA/2^bits) + oA + inl*4*y*(1 - y) + nA*w2
%            with y = x/FS, LSB = FS/2^bits
%     code = round(c), limited to 0 ... 2^bits - 1
%     um   = code*LSB/k                      value in the controller
%   The controller uses the nominal gain k, as firmware without a
%   calibration does. The ADC gain error gA is in LSB at full scale. The
%   INL term is a bow with the value inl at mid-scale and 0 at the ends.
%   Values and sources: pv4x4_config.m, section "Sensors and ADC".
%
%   MPPT_4x4.slx calls this function in the block "Sensors and ADC" at
%   the control sample time.

if s.on == 0
    Vm = V; Im = I;
    return
end
Vm = channel(V, s.kV, s.eV, s.oV, s.nV, w(1), w(3), s);
Im = channel(I, s.kI, s.eI, s.oI, s.nI, w(2), w(4), s);
end

function um = channel(u, k, e, o, n, w1, w2, s)
nc  = 2^s.bits;
lsb = s.FS / nc;
x   = k * u * (1 + e) + o + n * w1;
y   = min(max(x / s.FS, 0), 1);
c   = x / lsb * (1 + s.adc_gain / nc) + s.adc_off + s.adc_inl * 4 * y * (1 - y) + s.adc_n * w2;
code = min(max(round(c), 0), nc - 1);
um  = code * lsb / k;
end
