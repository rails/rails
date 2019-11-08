*   Add an option to disable logging of the job arguments when enqueuing and executing the job.

        class SensitiveJob < ApplicationJob
          self.log_arguments = false

          def perform(my_sensitive_argument)
          end
        end

    When dealing with sensitive arugments as password and tokens it is now possible to configure the job
    to not put the sensitive argument in the logs.

    *Rafael Mendonça França*

*   Changes in `queue_name_prefix` of a job no longer affects all other jobs. Fixes #37084.

    *Lucas Mansur*

*   Allow `Class` and `Module` instances to be serialized.

    *Kevin Deisz*

*   Log potential matches in `assert_enqueued_with` and `assert_performed_with`

    *Gareth du Plooy*

*   Add `at` argument to the `perform_enqueued_jobs` test helper.

    *John Crepezzi*, *Eileen Uchitelle*

*   `assert_enqueued_with` and `assert_performed_with` can now test jobs with relative delay.

    *Vlado Cingel*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activejob/CHANGELOG.md) for previous changes.
