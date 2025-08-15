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

*   Allow jobs to the interrupted and resumed with Continuations

    A job can use Continuations by including the `ActiveJob::Continuable`
    concern. Continuations split jobs into steps. When the queuing system
    is shutting down jobs can be interrupted and their progress saved.

    ```ruby
    class ProcessImportJob
      include ActiveJob::Continuable

      def perform(import_id)
        @import = Import.find(import_id)

        # block format
        step :initialize do
          @import.initialize
        end

        # step with cursor, the cursor is saved when the job is interrupted
        step :process do |step|
          @import.records.find_each(start: step.cursor) do |record|
            record.process
            step.advance! from: record.id
          end
        end

        # method format
        step :finalize

        private
          def finalize
            @import.finalize
          end
      end
    end
    ```

    *Donal McBreen*

*   Defer invocation of ActiveJob enqueue callbacks until after commit when
    `enqueue_after_transaction_commit` is enabled.

    *Will Roever*

*   Add `report:` option to `ActiveJob::Base#retry_on` and `#discard_on`

    When the `report:` option is passed, errors will be reported to the error reporter
    before being retried / discarded.

    *Andrew Novoselac*

*   Accept a block for `ActiveJob::ConfiguredJob#perform_later`.

    This was inconsistent with a regular `ActiveJob::Base#perform_later`.

    *fatkodima*

*   Raise a more specific error during deserialization when a previously serialized job class is now unknown.

    `ActiveJob::UnknownJobClassError` will be raised instead of a more generic
    `NameError` to make it easily possible for adapters to tell if the `NameError`
    was raised during job execution or deserialization.

    *Earlopain*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activejob/CHANGELOG.md) for previous changes.
