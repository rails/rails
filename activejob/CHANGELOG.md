*   Introduce `restore_attributes_on` to Active Job

    User will be able to define a class (or classes) that Active Job should
    preserve its attributes between when the job is enqueued and when the job
    gets deserialized and ready to be executed. This is useful when using with
    a subclass of `ActiveSupport::CurrentAttributes` as it will save and restore
    those attributes on `Current` class automatically.

    User can activate this functionality by putting this into their
    `ApplicationJob`:

        class ApplicationJob < ActiveJob::Base
          restore_attributes_on Current
        end

    *Prem Sichanugrist*

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
