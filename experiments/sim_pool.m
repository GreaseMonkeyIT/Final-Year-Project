function pool = sim_pool(nWorkers)
%SIM_POOL Start the parallel pool of the parsim runs with a limited number of workers.
%
%   pool = sim_pool(nWorkers) returns a pool of the 'Processes' profile
%   with nWorkers workers. If a pool with a different size is open, the
%   function closes it first. sim_pool() uses 4 workers.
%
%   Memory. Each worker loads MPPT_4x4.slx with Simscape Electrical and
%   commits about 2 GiB. On 2026-11-21, 16 workers committed 36.6 GiB on
%   a laptop with 15.2 GiB of RAM, and Windows used the page file. The
%   user asked to keep the runs at 10 to 12 GiB. 4 workers and the client
%   are inside this limit. The runs take longer, but the CPU (16 cores)
%   is not the limit.

if nargin < 1
    nWorkers = 4;
end
pool = gcp('nocreate');
if ~isempty(pool) && pool.NumWorkers ~= nWorkers
    delete(pool);
    pool = [];
end
if isempty(pool)
    % Stale jobs. On 2026-11-23 a job of a stopped run stayed in the queue
    % of the 'Processes' profile, and the next parpool waited at "Job
    % Queued" without an end. The function deletes the old jobs first and
    % tries the start three times.
    c = parcluster('Processes');
    for k = 1:3
        try
            delete(c.Jobs);
            pool = parpool(c, nWorkers);
            break
        catch err
            fprintf('sim_pool: start %d of 3 failed: %s\n', k, err.message);
            if k == 3, rethrow(err); end
            pause(60);
        end
    end
end
end
