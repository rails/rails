*   Bring back proc with arity of 1 in ActionMailer::Base.default proc
    since it was supported in Rails 5.0 but not deprecated.

    *Jimmy Bourassa*

*   Allow Action Mailer classes to configure their delivery job.

        class MyMailer < ApplicationMailer
          self.delivery_job = MyCustomDeliveryJob

          ...
        end

    *Matthew Mongeau*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actionmailer/CHANGELOG.md) for previous changes.
