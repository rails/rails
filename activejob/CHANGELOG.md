## Rails 6.1.7.3 (March 13, 2023) ##

*   No changes.


## Rails 6.1.7.2 (January 24, 2023) ##

*   No changes.


## Rails 6.1.7.1 (January 17, 2023) ##

*   No changes.


## Rails 6.1.7 (September 09, 2022) ##

*   No changes.


## Rails 6.1.6.1 (July 12, 2022) ##

*   No changes.


## Rails 6.1.6 (May 09, 2022) ##

*   No changes.


## Rails 6.1.5.1 (April 26, 2022) ##

*   No changes.


## Rails 6.1.5 (March 09, 2022) ##

*   No changes.


## Rails 6.1.4.7 (March 08, 2022) ##

*   No changes.


## Rails 6.1.4.6 (February 11, 2022) ##

*   No changes.


## Rails 6.1.4.5 (February 11, 2022) ##

*   No changes.


## Rails 6.1.4.4 (December 15, 2021) ##

*   No changes.


## Rails 6.1.4.3 (December 14, 2021) ##

*   No changes.


## Rails 6.1.4.2 (December 14, 2021) ##

*   No changes.


## Rails 6.1.4.1 (August 19, 2021) ##

*   No changes.


## Rails 6.1.4 (June 24, 2021) ##

*   No changes.


## Rails 6.1.3.2 (May 05, 2021) ##

*   No changes.


## Rails 6.1.3.1 (March 26, 2021) ##

*   No changes.


## Rails 6.1.3 (February 17, 2021) ##

*   No changes.


## Rails 6.1.2.1 (February 10, 2021) ##

*   No changes.


## Rails 6.1.2 (February 09, 2021) ##

*   No changes.


## Rails 6.1.1 (January 07, 2021) ##

*   Make `retry_job` return the job that was created.

    *Rafael Mendonça França*

*   Include `ActiveSupport::Testing::Assertions` in `ActiveJob::TestHelpers`.

    *Mikkel Malmberg*


## Rails 6.1.0 (December 09, 2020) ##

*   Recover nano precision when serializing `Time`, `TimeWithZone` and `DateTime` objects.

    *Alan Tan*

*   Deprecate `config.active_job.return_false_on_aborted_enqueue`.

    *Rafael Mendonça França*

*   Return `false` when enqueuing a job is aborted.

    *Rafael Mendonça França*

*   While using `perform_enqueued_jobs` test helper enqueued jobs must be stored for the later check with
    `assert_enqueued_with`.

    *Dmitry Polushkin*

*   `ActiveJob::TestCase#perform_enqueued_jobs` without a block removes performed jobs from the queue.

    That way the helper can be called multiple times and not perform a job invocation multiple times.

    ```ruby
    def test_jobs
      HelloJob.perform_later("rafael")
      perform_enqueued_jobs # only runs with "rafael"
      HelloJob.perform_later("david")
      perform_enqueued_jobs # only runs with "david"
    end
    ```

    *Étienne Barrié*

*   `ActiveJob::TestCase#perform_enqueued_jobs` will no longer perform retries:

    When calling `perform_enqueued_jobs` without a block, the adapter will
    now perform jobs that are **already** in the queue. Jobs that will end up in
    the queue afterwards won't be performed.

    This change only affects `perform_enqueued_jobs` when no block is given.

    *Edouard Chin*

*   Add queue name support to Que adapter.

    *Brad Nauta*, *Wojciech Wnętrzak*

*   Don't run `after_enqueue` and `after_perform` callbacks if the callback chain is halted.

        class MyJob < ApplicationJob
          before_enqueue { throw(:abort) }
          after_enqueue { # won't enter here anymore }
        end

    `after_enqueue` and `after_perform` callbacks will no longer run if the callback chain is halted.
    This behaviour is a breaking change and won't take effect until Rails 7.0.
    To enable this behaviour in your app right now, you can add in your app's configuration file
    `config.active_job.skip_after_callbacks_if_terminated = true`.

    *Edouard Chin*

*   Fix enqueuing and performing incorrect logging message.

    Jobs will no longer always log "Enqueued MyJob" or "Performed MyJob" when they actually didn't get enqueued/performed.

    ```ruby
      class MyJob < ApplicationJob
        before_enqueue { throw(:abort) }
      end

      MyJob.perform_later # Will no longer log "Enqueued MyJob" since job wasn't even enqueued through adapter.
    ```

    A new message will be logged in case a job couldn't be enqueued, either because the callback chain was halted or
    because an exception happened during enqueuing. (i.e. Redis is down when you try to enqueue your job)

    *Edouard Chin*

*   Add an option to disable logging of the job arguments when enqueuing and executing the job.

        class SensitiveJob < ApplicationJob
          self.log_arguments = false

          def perform(my_sensitive_argument)
          end
        end

    When dealing with sensitive arguments as password and tokens it is now possible to configure the job
    to not put the sensitive argument in the logs.

    *Rafael Mendonça França*

*   Changes in `queue_name_prefix` of a job no longer affects all other jobs.

    Fixes #37084.

    *Lucas Mansur*

*   Allow `Class` and `Module` instances to be serialized.

    *Kevin Deisz*

*   Log potential matches in `assert_enqueued_with` and `assert_performed_with`.

    *Gareth du Plooy*

*   Add `at` argument to the `perform_enqueued_jobs` test helper.

    *John Crepezzi*, *Eileen Uchitelle*

*   `assert_enqueued_with` and `assert_performed_with` can now test jobs with relative delay.

    *Vlado Cingel*

*   Add jitter to `ActiveJob::Exceptions.retry_on`.

    `ActiveJob::Exceptions.retry_on` now uses a random amount of jitter in order to
    prevent the [thundering herd effect](https://en.wikipedia.org/wiki/Thundering_herd_problem). Defaults to
    15% (represented as 0.15) but overridable via the `:jitter` option when using `retry_on`.
    Jitter is applied when an `Integer`, `ActiveSupport::Duration` or `:exponentially_longer`, is passed to the `wait` argument in `retry_on`.

    ```ruby
    retry_on(MyError, wait: :exponentially_longer, jitter: 0.30)
    ```

    *Anthony Ross*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activejob/CHANGELOG.md) for previous changes.
