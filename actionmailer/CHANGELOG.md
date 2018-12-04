## Rails 5.2.2 (December 04, 2018) ##

*   No changes.


## Rails 5.2.1.1 (November 27, 2018) ##

*   No changes.


## Rails 5.2.1 (August 07, 2018) ##

*   Ensure mail gem is eager autoloaded when eager load is true to prevent thread deadlocks.

    *Samuel Cochran*


## Rails 5.2.0 (April 09, 2018) ##

*   Bring back proc with arity of 1 in `ActionMailer::Base.default` proc
    since it was supported in Rails 5.0 but not deprecated.

    *Jimmy Bourassa*

*   Add `assert_enqueued_email_with` test helper.

        assert_enqueued_email_with ContactMailer, :welcome do
          ContactMailer.welcome.deliver_later
        end

    *Mikkel Malmberg*

*   Allow Action Mailer classes to configure their delivery job.

        class MyMailer < ApplicationMailer
          self.delivery_job = MyCustomDeliveryJob

          ...
        end

    *Matthew Mongeau*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actionmailer/CHANGELOG.md) for previous changes.
