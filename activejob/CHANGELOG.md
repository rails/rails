*   Allow `queue` option to `assert_no_enqueued_jobs`.

    Example:
    ```
    def test_no_logging
      assert_no_enqueued_jobs queue: 'default' do
        LoggingJob.set(queue: :some_queue).perform_later
      end
    end
    ```

    *bogdanvlviv*

*   Allow call `assert_enqueued_with` with no block.

    Example:
    ```
    def test_assert_enqueued_with
      MyJob.perform_later(1,2,3)
      assert_enqueued_with(job: MyJob, args: [1,2,3], queue: 'low')

      MyJob.set(wait_until: Date.tomorrow.noon).perform_later
      assert_enqueued_with(job: MyJob, at: Date.tomorrow.noon)
    end
    ```

    *bogdanvlviv*

*   Allow passing multiple exceptions to `retry_on`, and `discard_on`.

    *George Claghorn*

*   Pass the error instance as the second parameter of block executed by `discard_on`.

    Fixes #32853.

    *Yuji Yaginuma*

*   Remove support for Qu gem.

    Reasons are that the Qu gem wasn't compatible since Rails 5.1,
    gem development was stopped in 2014 and maintainers have
    confirmed its demise. See issue #32273

    *Alberto Almagro*

*   Add support for timezones to Active Job.

    Record what was the current timezone in effect when the job was
    enqueued and then restore when the job is executed in same way
    that the current locale is recorded and restored.

    *Andrew White*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*

*   Add support to define custom argument serializers.

    *Evgenii Pecherkin*, *Rafael Mendonça França*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activejob/CHANGELOG.md) for previous changes.
