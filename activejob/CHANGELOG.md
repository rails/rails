*   Add an `:only` option to `perform_enqueued_jobs` to filter jobs based on
    type.

    This allows specific jobs to be tested, while preventing others from
    being performed unnecessarily.

    Example:

        def test_hello_job
          assert_performed_jobs 1, only: HelloJob do
            HelloJob.perform_later('jeremy')
            LoggingJob.perform_later
          end
        end

    An array may also be specified, to support testing multiple jobs.

    Example:

        def test_hello_and_logging_jobs
          assert_nothing_raised do
            assert_performed_jobs 2, only: [HelloJob, LoggingJob] do
              HelloJob.perform_later('jeremy')
              LoggingJob.perform_later('stewie')
              RescueJob.perform_later('david')
            end
          end
        end

    Fixes #18802.

    *Michael Ryan*

*   Allow keyword arguments to be used with Active Job.

    Fixes #18741.

    *Sean Griffin*

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

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activejob/CHANGELOG.md) for previous changes.
