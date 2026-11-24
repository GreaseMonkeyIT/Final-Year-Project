#!/usr/bin/env bash
# One entry point for the runs of the project.
#
# Use (Git Bash, in the project folder):
#   bash run.sh             show the menu and type a number
#   bash run.sh <command>   run one command directly (list below)
#
# Commands:
#   setup     make the Python environment .venv (once, about 1 min)
#   check     test that MATLAB and a pool of workers start (about 1 min)
#   quick     smoke test of all the phases, few cases, results/quick (about 20 min)
#   rerun     the phases that the restart rule changes, plus the traces (about 5.25 h on 3 workers)
#   all       all the phases of the final tests, plus the traces (about 9 h)
#   phases    only the phases that you name, e.g. "bash run.sh phases p2 p3"
#   figures   draw the figures and summary.csv of the final review (about 2 min)
#   report    write the IEEE report FinalReport_MPPT.docx
#   deck      write the review slides FinalReview_MPPT.pptx
#   outputs   figures, then report, then deck
#   status    show the progress of a run
#   stop      stop a run after the phase that runs now
#   resume    remove the stop request, so that a new run can start
#
# A long run uses this window. Keep the window open until the run ends.
# Open a second Git Bash window for "bash run.sh status" or "bash run.sh stop".
# The settings below are the only values that you can need to change.

cd "$(dirname "$0")" || exit 1

# ---- Settings -------------------------------------------------------------
# Simulink workers. Each worker uses about 2 GiB of RAM. 3 workers keep the
# RAM at 10 to 12 GiB on a 16 GiB laptop.
WORKERS=${WORKERS:-3}
# Template of the review slides (the mid-review slides of batch 4).
DECK_TEMPLATE=${DECK_TEMPLATE:-"$HOME/Downloads/Batch-4_projectppt.pptx"}
# Earlier phase 1c results. "rerun" keeps their rows of Idea B, Idea C, PSO
# and GWO and runs only DIRECT again (a start-up of 4 s does not use the
# restart rule, so those rows do not change).
P1C_PRIOR=${P1C_PRIOR:-"results/archive_2026-11-23_second_run/final_p1c.mat"}
# ---------------------------------------------------------------------------

# MATLAB runs each phase in the folder of its script, so give it an absolute path.
case "$P1C_PRIOR" in
    /*|[A-Za-z]:*) ;;
    *) P1C_PRIOR="$(pwd -W 2>/dev/null || pwd)/$P1C_PRIOR" ;;
esac

PY=.venv/Scripts/python
[ -x "$PY" ] || PY=.venv/bin/python

need_py() {
    if [ ! -x "$PY" ]; then
        echo "The Python environment is missing. Run: bash run.sh setup"
        exit 1
    fi
}

not_busy() {
    # A second run beside a running one would delete the jobs of its pool
    # (sim_pool.m) and use too much RAM.
    if tasklist //FI "IMAGENAME eq MATLAB.exe" 2>/dev/null | grep -qi matlab; then
        echo "MATLAB runs now. Wait for the end, or close MATLAB first. See: bash run.sh status"
        exit 1
    fi
}

chain() {
    # Run the phases in $@ in order, each in its own MATLAB process.
    not_busy
    if [ -f results/STOP ]; then
        echo "results/STOP exists, so the run would stop at once. Run: bash run.sh resume"
        exit 1
    fi
    echo "Phases: $*"
    echo "Workers: $WORKERS. Log: results/final_runs.txt. MATLAB output: results/final_<phase>.out"
    echo "Started $(date '+%H:%M'). Keep this window open. In a second window: bash run.sh status"
    FINAL_WORKERS=$WORKERS bash experiments/run_final_all.sh "$@"
    echo "Ended $(date '+%H:%M')."
    bash "$0" status
}

do_cmd() {
    case "$1" in
    setup)
        py=$(command -v python3 || command -v python || command -v py)
        [ -n "$py" ] || { echo "Python 3 is not on the PATH. Install Python 3.10 or later."; exit 1; }
        "$py" -m venv .venv && PY=.venv/Scripts/python && { [ -x "$PY" ] || PY=.venv/bin/python; } \
            && "$PY" -m pip install -q -r requirements.txt && echo "Python environment ready in .venv"
        command -v matlab > /dev/null || echo "Note: matlab is not on the PATH. Add the bin folder of MATLAB to the PATH."
        ;;
    check)
        not_busy
        echo "MATLAB start and license (limit 300 s):"
        timeout 300 matlab -batch "disp(version); fprintf('Simulink license: %d, Simscape license: %d\n', license('test','Simulink'), license('test','Simscape'))" \
            || { echo "MATLAB did not start. See the notes in docs/notes/final_test_plan.md (2026-11-23, evening)."; exit 1; }
        echo "Pool of $WORKERS workers (limit 300 s):"
        timeout 300 matlab -batch "run('startup.m'); addpath('experiments'); t = tic; p = sim_pool($WORKERS); fprintf('Pool started in %.0f s\n', toc(t)); delete(p)" \
            || { echo "The pool did not start."; exit 1; }
        echo "Check passed."
        ;;
    quick)
        FINAL_QUICK=1 FINAL_P1C_PRIOR="$P1C_PRIOR" chain p1b p5 p4 compute p3n p1c p2 p3
        echo "Smoke test results are in results/quick. The .out files show any errors."
        ;;
    rerun)
        FINAL_P1C_PRIOR="$P1C_PRIOR" chain p1b p5 p4 compute p3n p1c p2 p3 traces
        ;;
    all)
        chain p1b p5 p4 compute p3n p1a p1c p1d p2 p3 traces
        ;;
    phases)
        shift
        [ $# -gt 0 ] || { echo "Name the phases, e.g.: bash run.sh phases p2 p3"; exit 1; }
        chain "$@"
        ;;
    figures)
        matlab -batch "run('reports/final_review/make_figures.m')"
        ;;
    report)
        need_py
        (cd reports/final_review && "../../$PY" build_report.py)
        ;;
    deck)
        need_py
        [ -f "$DECK_TEMPLATE" ] || { echo "Template not found: $DECK_TEMPLATE. Set DECK_TEMPLATE in run.sh."; exit 1; }
        (cd reports/final_review && "../../$PY" build_deck.py "$DECK_TEMPLATE")
        ;;
    outputs)
        bash "$0" figures && bash "$0" report && bash "$0" deck
        ;;
    status)
        echo "Last lines of results/final_runs.txt:"
        tail -n 8 results/final_runs.txt 2>/dev/null || echo "(no log yet)"
        last=$(grep -E ' start ' results/final_runs.txt 2>/dev/null | tail -n 1 | awk '{print $4}')
        if [ -n "$last" ] && ! grep -qE " end   $last " <(tail -n 1 results/final_runs.txt); then
            echo
            echo "Phase $last runs now. Last lines of results/final_$last.out:"
            tail -n 4 "results/final_$last.out" 2>/dev/null
        fi
        [ -f results/STOP ] && echo && echo "results/STOP exists: the run stops after this phase."
        n=$(tasklist //FI "IMAGENAME eq MATLAB.exe" 2>/dev/null | grep -ci matlab)
        echo
        echo "MATLAB processes: $n"
        ;;
    stop)
        touch results/STOP
        echo "Stop requested. The phase that runs now ends normally, then the run stops."
        echo "Before the next run: bash run.sh resume"
        ;;
    resume)
        rm -f results/STOP
        echo "Stop request removed."
        ;;
    *)
        echo "Unknown command: $1. Run \"bash run.sh\" for the menu."
        exit 1
        ;;
    esac
}

if [ $# -gt 0 ]; then
    do_cmd "$@"
    exit $?
fi

# Menu
items=(setup check quick rerun all figures report deck outputs status stop resume)
text=("Make the Python environment (once)"
      "Test that MATLAB and the workers start (1 min)"
      "Smoke test of all phases (20 min)"
      "Run again the phases that the restart rule changes (5.25 h)"
      "Run all the final tests (9 h)"
      "Draw the figures and the summary table (2 min)"
      "Write the IEEE report (.docx)"
      "Write the review slides (.pptx)"
      "Figures, report and slides"
      "Show the progress of a run"
      "Stop a run after the current phase"
      "Remove the stop request")
echo "Runs of the project (settings at the top of run.sh)"
for i in "${!items[@]}"; do
    printf "  %2d  %-8s %s\n" $((i + 1)) "${items[$i]}" "${text[$i]}"
done
read -r -p "Number: " n
if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le ${#items[@]} ]; then
    do_cmd "${items[$((n - 1))]}"
else
    echo "No command chosen."
fi
