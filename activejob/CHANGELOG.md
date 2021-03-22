*   Stop executing perform method when `retry_job` is called

    The `perform` method can now be automatically interrupted if `retry_job`
    is called, preventing weird states where a job continues to execute after
    it has been re-enqueued.

    *Daniel Morton*

*   Communicate enqueue failures to callers of `perform_later`.

    `perform_later` can now optionally take a block which will execute after
    the adapter attempts to enqueue the job. The block will receive the job
    instance as an argument even if the enqueue was not successful.
    Additionally, `ActiveJob` adapters now have the ability to raise an
    `ActiveJob::EnqueueError` which will be caught and stored in the job
    instance so code attempting to enqueue jobs can inspect any raised
    `EnqueueError` using the block.

        MyJob.perform_later do |job|
          unless job.successfully_enqueued?
            if job.enqueue_error&.message == "Redis was unavailable"
              # invoke some code that will retry the job after a delay
            end
          end
        end

    *Daniel Morton*

*   Don't log rescuable exceptions defined with `rescue_from`.

    *Hu Hailin*

*   Allow `rescue_from` to rescue all exceptions.

    *Adrianna Chang*, *Étienne Barrié*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activejob/CHANGELOG.md) for previous changes.
