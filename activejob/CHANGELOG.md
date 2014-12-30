* `ActiveJob::Base.deserialize` delegates to the job class

  Since `ActiveJob::Base#deserialize` can be overriden by subclasses (like `ActiveJob::Base#serialize`)
  this allows jobs to attach arbitrary metadata when they get serialized and read it back when they get
  performed. E.g.

      class DeliverWebhookJob < ActiveJob::Base
        def serialize
          super.merge('attempt_number' => (@attempt_number || 0) + 1)
        end

        def deserialize(job_data)
          super(job_data)
          @attempt_number = job_data['attempt_number']
        end

        rescue_from(TimeoutError) do |ex|
          raise ex if @attempt_number > 5
          retry_job(wait: 10)
        end
      end

  *Isaac Seymour*


Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activejob/CHANGELOG.md) for previous changes.
