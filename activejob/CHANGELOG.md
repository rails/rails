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

*   Add jitter to :exponentially_longer

    ActiveJob::Exceptions.retry_on with :exponentially_longer now uses a random amount of jitter in order to
    prevent the [thundering herd effect.](https://en.wikipedia.org/wiki/Thundering_herd_problem).  Defaults to
    15% (represented as 0.15) but overridable via the `:jitter` option when using `retry_on`.
    Jitter is applied when an `Integer`, `ActiveSupport::Duration` or `exponentially_longer`, is passed to the `wait` argument in `retry_on`.

    retry_on(MyError, wait: :exponentially_longer, jitter: 0.30)

    *Anthony Ross*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activejob/CHANGELOG.md) for previous changes.
