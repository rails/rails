## Rails 7.1.5.1 (December 10, 2024) ##

*   No changes.


## Rails 7.1.5 (October 30, 2024) ##

*   No changes.


## Rails 7.1.4.2 (October 23, 2024) ##

*   No changes.


## Rails 7.1.4.1 (October 15, 2024) ##

*   No changes.


## Rails 7.1.4 (August 22, 2024) ##

*   Register autoload for `ActiveJob::Arguments`.

    *Rafael Mendonça França*


## Rails 7.1.3.4 (June 04, 2024) ##

*   No changes.


## Rails 7.1.3.3 (May 16, 2024) ##

*   No changes.


## Rails 7.1.3.2 (February 21, 2024) ##

*   No changes.


## Rails 7.1.3.1 (February 21, 2024) ##

*   No changes.


## Rails 7.1.3 (January 16, 2024) ##

*   Do not trigger immediate loading of `ActiveJob::Base` when loading `ActiveJob::TestHelper`.

    *Maxime Réty*

*   Preserve the serialized timezone when deserializing `ActiveSupport::TimeWithZone` arguments.

    *Joshua Young*

*   Fix ActiveJob arguments serialization to correctly serialize String subclasses having custom serializers.

    *fatkodima*


## Rails 7.1.2 (November 10, 2023) ##

*   No changes.


## Rails 7.1.1 (October 11, 2023) ##

*   Don't log enqueuing details when the job wasn't enqueued.

    *Dustin Brown*


## Rails 7.1.0 (October 05, 2023) ##

*   No changes.


## Rails 7.1.0.rc2 (October 01, 2023) ##

*   Make sure `scheduled_at` is a Time object when asserting enqueued jobs.

    *Rafael Mendonça França*


## Rails 7.1.0.rc1 (September 27, 2023) ##

*   Set `scheduled_at` attribute as a Time object instead of epoch seconds, and serialize and deserialize the value
    when enqueued. Assigning a numeric/epoch value to scheduled_at= is deprecated; use a Time object instead.

    Deserializes `enqueued_at` as a Time instead of ISO8601 String.

    *Ben Sheldon*

*   Clarify the backoff strategy for the recommended `:wait` option when retrying jobs

    `wait: :exponentially_longer` is waiting polynomially longer, so it is now recommended to use `wait: :polynomially_longer` to keep the same behavior.

    *Victor Mours*


## Rails 7.1.0.beta1 (September 13, 2023) ##

*   Fix Active Job log message to correctly report a job failed to enqueue
    when the adapter raises an `ActiveJob::EnqueueError`.

    *Ben Sheldon*

*   Add `after_discard` method.

    This method lets job authors define a block which will be run when a job is about to be discarded. For example:

    ```ruby
    class AfterDiscardJob < ActiveJob::Base
      after_discard do |job, exception|
        Rails.logger.info("#{job.class} raised an exception: #{exception}")
      end

      def perform
        raise StandardError
      end
    end
    ```

    The above job will run the block passed to `after_discard` after the job is discarded. The exception will
    still be raised after the block has been run.

    *Rob Cardy*

*   Fix deserialization of ActiveSupport::Duration

    Previously, a deserialized Duration would return an array from Duration#parts.
    It will now return a hash just like a regular Duration.

    This also fixes an error when trying to add or subtract from a deserialized Duration
    (eg `duration + 1.year`).

    *Jonathan del Strother*

*   `perform_enqueued_jobs` is now compatible with all Active Job adapters

    This means that methods that depend on it, like Action Mailer's `assert_emails`,
    will work correctly even if the test adapter is not used.

    *Alex Ghiculescu*

*   Allow queue adapters to provide a custom name by implementing `queue_adapter_name`

    *Sander Verdonschot*

*   Log background job enqueue callers

    Add `verbose_enqueue_logs` configuration option to display the caller
    of background job enqueue in the log to help with debugging.

    Example log line:

    ```
    Enqueued AvatarThumbnailsJob (Job ID: ab528951-41fb-4c48-9129-3171791c27d6) to Sidekiq(default) with arguments: 1092412064
    ↳ app/models/user.rb:421:in `generate_avatar_thumbnails'
    ```

    Enabled in development only for new and upgraded applications. Not recommended for use
    in the production environment since it relies on Ruby's `Kernel#caller` which is fairly slow.

    *fatkodima*

*   Set `provider_job_id` for Backburner jobs

    *Cameron Matheson*

*   Add `perform_all_later` to enqueue multiple jobs at once

    This adds the ability to bulk enqueue jobs, without running callbacks, by
    passing multiple jobs or an array of jobs. For example:

    ```ruby
    ActiveJob.perform_all_later(MyJob.new("hello", 42), MyJob.new("world", 0))

    user_jobs = User.pluck(:id).map { |id| UserJob.new(user_id: id) }
    ActiveJob.perform_all_later(user_jobs)
    ```

    This can greatly reduce the number of round-trips to the queue datastore.
    For queue adapters that do not implement the new `enqueue_all` method, we
    fall back to enqueuing jobs individually. The Sidekiq adapter implements
    `enqueue_all` with `push_bulk`.

    This method does not use the existing `enqueue.active_job` event, but adds a
    new event `enqueue_all.active_job`.

    *Sander Verdonschot*

*   Don't double log the `job` when using `ActiveRecord::QueryLog`

    Previously if you set `config.active_record.query_log_tags` to an array that included
    `:job`, the job name would get logged twice. This bug has been fixed.

    *Alex Ghiculescu*

*   Add support for Sidekiq's transaction-aware client

    *Jonathan del Strother*

*   Remove QueAdapter from Active Job.

    After maintaining Active Job QueAdapter by Rails and Que side
    to support Ruby 3 keyword arguments and options provided as top level keywords,
    it is quite difficult to maintain it this way.

    Active Job Que adapter can be included in the future version of que gem itself.

    *Yasuo Honda*

*   Fix BigDecimal (de)serialization for adapters using JSON.

    Previously, BigDecimal was listed as not needing a serializer.  However,
    when used with an adapter storing the job arguments as JSON, it would get
    serialized as a simple String, resulting in deserialization also producing
    a String (instead of a BigDecimal).

    By using a serializer, we ensure the round trip is safe.

    To ensure applications using BigDecimal job arguments are not subject to
    race conditions during deployment (where a replica running a version of
    Rails without BigDecimalSerializer fails to deserialize an argument
    serialized with it), `ActiveJob.use_big_decimal_serializer` is disabled by
    default, and can be set to true in a following deployment..

    *Sam Bostock*

*   Preserve full-precision `enqueued_at` timestamps for serialized jobs,
    allowing more accurate reporting of how long a job spent waiting in the
    queue before it was performed.

    Retains IS08601 format compatibility.

    *Jeremy Daer*

*   Add `--parent` option to job generator to specify parent class of job.

    Example:

    `bin/rails g job process_payment --parent=payment_job` generates:

    ```ruby
    class ProcessPaymentJob < PaymentJob
      # ...
    end
    ```

    *Gannon McGibbon*

*   Add more detailed description to job generator.

    *Gannon McGibbon*

*   `perform.active_job` notification payloads now include `:db_runtime`, which
    is the total time (in ms) taken by database queries while performing a job.
    This value can be used to better understand how a job's time is spent.

    *Jonathan Hefner*

*   Update `ActiveJob::QueueAdapters::QueAdapter` to remove deprecation warning.

    Remove a deprecation warning introduced in que 1.2 to prepare for changes in
    que 2.0 necessary for Ruby 3 compatibility.

    *Damir Zekic* and *Adis Hasovic*

*   Add missing `bigdecimal` require in `ActiveJob::Arguments`

    Could cause `uninitialized constant ActiveJob::Arguments::BigDecimal (NameError)`
    when loading Active Job in isolation.

    *Jean Boussier*

*   Allow testing `discard_on/retry_on ActiveJob::DeserializationError`

    Previously in `perform_enqueued_jobs`, `deserialize_arguments_if_needed`
    was called before calling `perform_now`. When a record no longer exists
    and is serialized using GlobalID this led to raising
    an `ActiveJob::DeserializationError` before reaching `perform_now` call.
    This behavior makes difficult testing the job `discard_on/retry_on` logic.

    Now `deserialize_arguments_if_needed` call is postponed to when `perform_now`
    is called.

    Example:

    ```ruby
    class UpdateUserJob < ActiveJob::Base
      discard_on ActiveJob::DeserializationError

      def perform(user)
        # ...
      end
    end

    # In the test
    User.destroy_all
    assert_nothing_raised do
      perform_enqueued_jobs only: UpdateUserJob
    end
    ```

    *Jacopo Beschi*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activejob/CHANGELOG.md) for previous changes.
