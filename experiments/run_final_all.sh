#!/usr/bin/env bash
# Run the phases of the final tests in order (docs/notes/final_test_plan.md).
#
# Each phase runs in its own MATLAB process, so that the RAM of one phase
# is free before the next starts. The script writes the start time, the
# end time and the exit code of each phase to results/final_runs.txt and
# the MATLAB output to results/final_<phase>.out. A phase that fails does
# not stop the next phases.
#
# Use (Git Bash, from the project folder):
#   bash experiments/run_final_all.sh            all phases
#   bash experiments/run_final_all.sh p1b p2     only these phases
#
# Order: the static phases first (p1b, p5, p4, compute: about 1.5 h), then
# the Simulink phases (p1a, p1c, p1d, p2, p3: about 6.5 h on 3 workers).
# p1c and p1d need the results of p1b. p3 and p4 need oahu_fit, which the
# default order does not run again (its inputs did not change since
# 2026-11-21): run "bash experiments/run_final_all.sh oahu_fit" first on a
# new copy of the project.

cd "$(dirname "$0")/.." || exit 1
phases=("$@")
if [ ${#phases[@]} -eq 0 ]; then
    phases=(p1b p5 p4 compute p3n p1a p1c p1d p2 p3)
fi
log=results/final_runs.txt

# Start-up probe. On 2026-11-23 the MathWorks service host used 14 cores,
# and MATLAB stopped at the start without an end. Before each phase, the
# script starts MATLAB once with a limit of 300 s and tries three times.
# If all three tries fail, the script stops the chain. The log also gets
# the CPU use of the service host (CPU seconds in 5 s, about 0 when idle).
probe() {
    local k
    for k in 1 2 3; do
        if timeout 300 matlab -batch "exit" > /dev/null 2>&1; then return 0; fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') probe $k of 3 failed" >> "$log"
        sleep 120
    done
    return 1
}
hostcpu() {
    powershell -NoProfile -Command "\$p = Get-Process MathWorksServiceHost -ErrorAction SilentlyContinue | Select-Object -First 1; if (\$p) { \$a = \$p.CPU; Start-Sleep 5; \$p.Refresh(); '{0:N1}' -f (\$p.CPU - \$a) } else { 'none' }" 2>/dev/null | tr -d '\r'
}

for ph in "${phases[@]}"; do
    if [ "$ph" = "oahu_fit" ]; then script=experiments/oahu_fit.m; else script=experiments/run_final_$ph.m; fi
    if [ -f results/STOP ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') results/STOP exists: chain stopped before $ph" >> "$log"
        break
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') service host CPU s in 5 s: $(hostcpu)" >> "$log"
    if ! probe; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') MATLAB does not start: chain stopped before $ph" >> "$log"
        break
    fi
    start=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$start start $ph" >> "$log"
    matlab -batch "run('$script')" > "results/final_$ph.out" 2>&1
    code=$?
    echo "$(date '+%Y-%m-%d %H:%M:%S') end   $ph (exit $code)" >> "$log"
done
