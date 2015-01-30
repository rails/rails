*   Add optional arguments to JobGenerator, to generate arguments within perform

    Example:

        rails generate job send_csv account user

    Generates:

        class SendCsvJob < ActiveJob::Base
          def perform(account, user)
            # Do something later
          end
        end

    *Dan Ott*

*   Add `:only` option to `assert_enqueued_jobs`, to check the number of times
    a specific kind of job is enqueued.

    Example:

        def test_logging_job
          assert_enqueued_jobs 1, only: LoggingJob do
            LoggingJob.perform_later
            HelloJob.perform_later('jeremy')
          end
        end

    *George Claghorn*

*   `ActiveJob::Base.deserialize` delegates to the job class.

    Since `ActiveJob::Base#deserialize` can be overridden by subclasses (like
    `ActiveJob::Base#serialize`) this allows jobs to attach arbitrary metadata
    when they get serialized and read it back when they get performed.

    Example:

        class DeliverWebhookJob < ActiveJob::Base
          def serialize
            super.merge('attempt_number' => (@attempt_number || 0) + 1)
          end

          def deserialize(job_data)
            super
            @attempt_number = job_data['attempt_number']
          end

          rescue_from(TimeoutError) do |exception|
            raise exception if @attempt_number > 5
            retry_job(wait: 10)
          end
        end

    *Isaac Seymour*

*  Started project.
