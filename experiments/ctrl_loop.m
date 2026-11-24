function [tAll, tDec, tOv, nDec, tCall, phDec] = ctrl_loop(V, I, p, nrep)
%CTRL_LOOP Execution time of mppt_controller.m on a recorded input series.
%
%   [tAll, tDec, tOv, nDec, tCall, phDec] = ctrl_loop(V, I, p, nrep) calls
%   mppt_controller.m once for each sample of V and I, as the controller
%   runs in each control sample Tc, and measures the time inside the
%   compiled code (run_final_compute.m makes the MEX file with MATLAB
%   Coder). Time from MATLAB would mostly measure the cost of the MEX call.
%     tAll   time of nrep full passes [s]
%     tDec   time of the decision calls in nrep passes, timer included [s]
%     tOv    time of the same number of empty timer pairs [s] (the timer
%            cost, to subtract from tDec)
%     nDec   decisions in one pass (the samples at the end of an MPPT
%            period, where the output Vm changes)
%     tCall  time of each decision call in the last pass [s] (column)
%     phDec  phase after each decision: 1 search, 2 local stage (column)
%   The first call of each pass sets p.reset = 1, so each pass starts from
%   the first state. The same inputs give the same decisions in each pass.
%   Made on 2026-11-22 for the final tests (docs/notes/final_test_plan.md).
%   Changed on 2026-11-22: the first version subtracted a pass with
%   p.alg = 0, which runs other code. The decision time (under 1 us) was
%   then smaller than the noise of the difference.

n  = numel(V);
pR = p;  pR.reset = 1;
p0 = p;  p0.reset = 0;
acc = 0;                                   % Keeps the results in use

% Untimed pass: the samples with a decision.
isDec = false(n, 1);
phD = zeros(n, 1);
Vprev = -1;
for k = 1:n
    pk = p0;
    if k == 1
        pk = pR;
    end
    [D, Vm, ~, ph] = mppt_controller(V(k), I(k), pk);
    if Vm ~= Vprev
        isDec(k) = true;
        phD(k) = ph;
        Vprev = Vm;
    end
    acc = acc + D;
end
nDec = sum(isDec);
phDec = phD(isDec);

% Full passes.
tAll = 0;
for r = 1:nrep
    t0 = tic;
    D = mppt_controller(V(1), I(1), pR);
    for k = 2:n
        D = mppt_controller(V(k), I(k), p0);
    end
    tAll = tAll + toc(t0);
    acc = acc + D;
end

% Passes with a timer around each decision call.
tDec = 0;
tCall = zeros(nDec, 1);
for r = 1:nrep
    j = 0;
    for k = 1:n
        pk = p0;
        if k == 1
            pk = pR;
        end
        if isDec(k)
            t0 = tic;
            D = mppt_controller(V(k), I(k), pk);
            dt = toc(t0);
            tDec = tDec + dt;
            j = j + 1;
            tCall(j) = dt;
        else
            D = mppt_controller(V(k), I(k), pk);
        end
        acc = acc + D;
    end
end

% Cost of the timer pair alone.
tOv = 0;
for r = 1:nrep
    for j = 1:nDec
        t0 = tic;
        tOv = tOv + toc(t0);
    end
end
if acc < -1                                % Never true: stops the compiler from removing the loops
    tAll = -1;
end
end
