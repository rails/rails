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
