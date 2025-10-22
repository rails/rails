*   Add rate limiting functionality for Active Job

    Similar to ActionController's rate limit feature, jobs can now limit
    their execution frequency using the `rate_limit` method.
    This helps prevent resource overload and respect third-party API limits.

    ```ruby
    class ExternalApiCallJob < ApplicationJob
        rate_limit to: 10, within: 1.second, name: "burst"
        rate_limit to: 1000, within: 1.hour, name: "sustained"
    end
    ```

    *heka1024*

*   Add structured events for Active Job:
    - `active_job.enqueued`
    - `active_job.bulk_enqueued`
    - `active_job.started`
    - `active_job.completed`
    - `active_job.retry_scheduled`
    - `active_job.retry_stopped`
    - `active_job.discarded`
    - `active_job.interrupt`
    - `active_job.resume`
    - `active_job.step_skipped`
    - `active_job.step_started`
    - `active_job.step`

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activejob/CHANGELOG.md) for previous changes.
