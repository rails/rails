## Rails 8.1.2 (January 08, 2026) ##

*   Fix `ActiveJob.perform_all_later` to respect `job_class.enqueue_after_transaction_commit`.

    Previously, `perform_all_later` would enqueue all jobs immediately, even if
    they had `enqueue_after_transaction_commit = true`. Now it correctly defers
    jobs with this setting until after transaction commits, matching the behavior
    of `perform_later`.

    *OuYangJinTing*

*   Fix using custom serializers with `ActiveJob::Arguments.serialize` when
    `ActiveJob::Base` hasn't been loaded.

    *Hartley McGuire*

## Rails 8.1.1 (October 28, 2025) ##

*   Only index new serializers.

    *Jesse Sharps*


## Rails 8.1.0 (October 22, 2025) ##

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

    *Adrianna Chang*

*   Deprecate built-in `sidekiq` adapter.

    If you're using this adapter, upgrade to `sidekiq` 7.3.3 or later to use the `sidekiq` gem's adapter.

    *fatkodima*

*   Remove deprecated internal `SuckerPunch` adapter in favor of the adapter included with the `sucker_punch` gem.

    *Rafael Mendonça França*

*   Remove support to set `ActiveJob::Base.enqueue_after_transaction_commit` to `:never`, `:always` and `:default`.

    *Rafael Mendonça França*

*   Remove deprecated `Rails.application.config.active_job.enqueue_after_transaction_commit`.

    *Rafael Mendonça França*

*   `ActiveJob::Serializers::ObjectSerializers#klass` method is now public.

    Custom Active Job serializers must have a public `#klass` method too.
    The returned class will be index allowing for faster serialization.

    *Jean Boussier*

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
