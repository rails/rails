*   Make Active Job transaction aware when used conjointly with Active Record.

    A common mistake with Active Job is to enqueue jobs from inside a transaction,
    causing them to potentially be picked and ran by another process, before the
    transaction is committed, which result in various errors.

    ```ruby
    Topic.transaction do
      topic = Topic.create(...)
      NewTopicNotificationJob.perform_later(topic)
    end
    ```

    Now Active Job will automatically defer the enqueuing to after the transaction is committed,
    and drop the job if the transaction is rolled back.

    Various queue implementations can chose to disable this behavior, and users can disable it,
    or force it on a per job basis:

    ```ruby
    class NewTopicNotificationJob < ApplicationJob
      self.enqueue_after_transaction_commit = false # or `true`
    end
    ```

    *Jean Boussier*, *Cristian Bica*

*   Do not trigger immediate loading of `ActiveJob::Base` when loading `ActiveJob::TestHelper`.

    *Maxime Réty*

*   Preserve the serialized timezone when deserializing `ActiveSupport::TimeWithZone` arguments.

    *Joshua Young*

*   Remove deprecated `:exponentially_longer` value for the `:wait` in `retry_on`.

    *Rafael Mendonça França*

*   Remove deprecated support to set numeric values to `scheduled_at` attribute.

    *Rafael Mendonça França*

*   Deprecate `Rails.application.config.active_job.use_big_decimal_serialize`.

    *Rafael Mendonça França*

*   Remove deprecated primitive serializer for `BigDecimal` arguments.

    *Rafael Mendonça França*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activejob/CHANGELOG.md) for previous changes.
