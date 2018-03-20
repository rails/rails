## Rails 5.2.0.rc2 (March 20, 2018) ##

*   No changes.


## Rails 5.2.0.rc1 (January 30, 2018) ##

*   Bring back proc with arity of 1 in `ActionMailer::Base.default` proc
    since it was supported in Rails 5.0 but not deprecated.

    *Jimmy Bourassa*


## Rails 5.2.0.beta2 (November 28, 2017) ##

*   No changes.


## Rails 5.2.0.beta1 (November 27, 2017) ##

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
