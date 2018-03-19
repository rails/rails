*   Add an adapter for using `faktory_worker_ruby`.

    To use Faktory set the queue_adapter like this:

    `config.active_job.queue_adapter = :faktory`

    *Jeremy Green*

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
