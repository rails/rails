## Rails 5.1.2 (June 26, 2017) ##

*   No changes.


## Rails 5.1.1 (May 12, 2017) ##

*   No changes.


## Rails 5.1.0 (April 27, 2017) ##

*   Change logging instrumentation to log errors when a job raises an exception.

    Fixes #26848.

    *Steven Bull*

*   Correctly set test adapter when configure the queue adapter on a per job.

    Fixes #26360.

    *Yuji Yaginuma*

*   Removed deprecated support to passing the adapter class to `.queue_adapter`.

    *Rafael Mendonça França*

*   Removed deprecated `#original_exception` in `ActiveJob::DeserializationError`.

    *Rafael Mendonça França*

*   Added instance variable `@queue` to JobWrapper.

    This will fix issues in [resque-scheduler](https://github.com/resque/resque-scheduler) `#job_to_hash` method,
    so we can use `#enqueue_delayed_selection`, `#remove_delayed` method in resque-scheduler smoothly.

    *mu29*

*   Yield the job instance so you have access to things like `job.arguments` on the custom logic after retries fail.

    *DHH*

*   Added declarative exception handling via `ActiveJob::Base.retry_on` and `ActiveJob::Base.discard_on`.

    Examples:

        class RemoteServiceJob < ActiveJob::Base
          retry_on CustomAppException # defaults to 3s wait, 5 attempts
          retry_on AnotherCustomAppException, wait: ->(executions) { executions * 2 }
          retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
          retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 10
          discard_on ActiveJob::DeserializationError

          def perform(*args)
            # Might raise CustomAppException or AnotherCustomAppException for something domain specific
            # Might raise ActiveRecord::Deadlocked when a local db deadlock is detected
            # Might raise Net::OpenTimeout when the remote service is down
          end
        end

    *DHH*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activejob/CHANGELOG.md) for previous changes.
