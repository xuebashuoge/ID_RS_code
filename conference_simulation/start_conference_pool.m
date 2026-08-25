function pool = start_conference_pool(requested_workers)
%START_CONFERENCE_POOL Start a thread pool, with a process-pool fallback.

    pool = gcp('nocreate');
    if ~isempty(pool)
        return;
    end

    requested_workers = max(1, floor(requested_workers));
    try
        pool = parpool('threads', requested_workers);
        fprintf('Started thread pool with %d workers.\n', pool.NumWorkers);
    catch thread_error
        warning('conference:ThreadPoolFallback', ...
            'Thread pool unavailable (%s). Trying a process pool.', ...
            thread_error.message);
        pool = parpool('local', requested_workers);
        fprintf('Started process pool with %d workers.\n', pool.NumWorkers);
    end
end
