*   Update `ActiveJob::QueueAdapters::QueAdapter` te remove deprecation warning

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
    This behaviour makes difficult testing the job `discard_on/retry_on` logic.

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
