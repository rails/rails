## Rails 5.1.0.alpha ##

*   Yield the job instance so you have access to things like `job.arguments` on the custom logic after retries fail.

    *DHH*

*   Added declarative exception handling via `ActiveJob::Base.retry_on` and `ActiveJob::Base.discard_on`. 

    Examples:

        class RemoteServiceJob < ActiveJob::Base
          retry_on CustomAppException # defaults to 3s wait, 5 attempts
          retry_on AnotherCustomAppException, wait: ->(executions) { executions * 2 }
          retry_on ActiveRecord::StatementInvalid, wait: 5.seconds, attempts: 3
          retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 10
          discard_on ActiveJob::DeserializationError

          def perform(*args)
            # Might raise CustomAppException or AnotherCustomAppException for something domain specific
            # Might raise ActiveRecord::StatementInvalid when a local db deadlock is detected
            # Might raise Net::OpenTimeout when the remote service is down
          end
        end

    *DHH*

*   Added instance variable `@queue` to JobWrapper.

    This will fix issues in [resque-scheduler](https://github.com/resque/resque-scheduler) `#job_to_hash` method,
    so we can use `#enqueue_delayed_selection`, `#remove_delayed` method in resque-scheduler smoothly.

    *mu29*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activejob/CHANGELOG.md) for previous changes.
