function st = gmppt_init(p) %#ok<INUSD>
%GMPPT_INIT State of the global search. PLACEHOLDER.
%
%   st = gmppt_init(p) returns the state at the start of a global search.
%   p is the mppt struct of pv4x4_config. mppt_controller.m calls it once
%   at start-up and again before each new search (restart).
%
%   This file is a placeholder. It holds the interface only. The global
%   searches of the preliminary study are archived in
%   archive/2026-11-21_post_midreview/src/controller/.
%
%   Interface rules for a replacement:
%     - st must have the field np (search probes applied so far). The
%       controller sends st.np to the logging output "np" of the model.
%     - Every field must have a fixed size, so that Simulink Coder can
%       generate code. Size sample arrays from p.Drep (1 x p.Nmax).

st.np = 0;
end
