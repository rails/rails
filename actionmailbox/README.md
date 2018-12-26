# Action Mailbox

Action Mailbox routes incoming emails to controller-like mailboxes for processing in Rails. It ships with ingresses for Amazon SES, Mailgun, Mandrill, and SendGrid. You can also handle inbound mails directly via the built-in Postfix ingress.

The inbound emails are turned into `InboundEmail` records using Active Record and feature lifecycle tracking, storage of the original email on cloud storage via Active Storage, and responsible data handling with on-by-default incineration.

These inbound emails are routed asynchronously using Active Job to one or several dedicated mailboxes, which are capable of interacting directly with the rest of your domain model.


## How does this compare to Action Mailer's inbound processing?

Rails has long had an anemic way of [receiving emails using Action Mailer](https://guides.rubyonrails.org/action_mailer_basics.html#receiving-emails), but it was poorly fleshed out, lacked cohesion with the task of sending emails, and offered no help on integrating with popular inbound email processing platforms. Action Mailbox supersedes the receiving part of Action Mailer, which will be deprecated in due course.


## Installing

Assumes a Rails 5.2+ application:

1. Install the gem:

    ```ruby
    # Gemfile
    gem "actionmailbox", github: "rails/actionmailbox", require: "action_mailbox"
    ```

1. Install migrations needed for InboundEmail (and ensure Active Storage is setup)

   ```
   ./bin/rails action_mailbox:install
   ./bin/rails db:migrate
   ```

## Configuring

### Amazon SES

1. Install the [`aws-sdk-sns`](https://rubygems.org/gems/aws-sdk-sns) gem:

   ```ruby
   # Gemfile
   gem "aws-sdk-sns", ">= 1.9.0", require: false
   ```

2. Tell Action Mailbox to accept emails from SES:

   ```ruby
   # config/environments/production.rb
   config.action_mailbox.ingress = :amazon
   ```

3. [Configure SES][ses-docs] to deliver emails to your application via POST requests
   to `/rails/action_mailbox/amazon/inbound_emails`. If your application lived at `https://example.com`, you would specify
   the fully-qualified URL `https://example.com/rails/action_mailbox/amazon/inbound_emails`.

[ses-docs]: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/receiving-email-notifications.html

### Mailgun

1. Give Action Mailbox your [Mailgun API key][mailgun-api-key] so it can authenticate requests to the Mailgun ingress.

   Use `rails credentials:edit` to add your API key to your application's encrypted credentials under
   `action_mailbox.mailgun_api_key`, where Action Mailbox will automatically find it:

   ```yaml
   action_mailbox:
     mailgun_api_key: ...
   ```

   Alternatively, provide your API key in the `MAILGUN_INGRESS_API_KEY` environment variable.

2. Tell Action Mailbox to accept emails from Mailgun:

   ```ruby
   # config/environments/production.rb
   config.action_mailbox.ingress = :mailgun
   ```

3. [Configure Mailgun][mailgun-forwarding] to forward inbound emails to `/rails/action_mailbox/mailgun/inbound_emails/mime`.
   If your application lived at `https://example.com`, you would specify the fully-qualified URL
   `https://example.com/rails/action_mailbox/mailgun/inbound_emails/mime`.

[mailgun-api-key]: https://help.mailgun.com/hc/en-us/articles/203380100-Where-can-I-find-my-API-key-and-SMTP-credentials-
[mailgun-forwarding]: https://documentation.mailgun.com/en/latest/user_manual.html#receiving-forwarding-and-storing-messages

### Mandrill

1. Give Action Mailbox your Mandrill API key so it can authenticate requests to the Mandrill ingress.

   Use `rails credentials:edit` to add your API key to your application's encrypted credentials under
   `action_mailbox.mandrill_api_key`, where Action Mailbox will automatically find it:

   ```yaml
   action_mailbox:
     mandrill_api_key: ...
   ```

   Alternatively, provide your API key in the `MANDRILL_INGRESS_API_KEY` environment variable.

2. Tell Action Mailbox to accept emails from Mandrill:

   ```ruby
   # config/environments/production.rb
   config.action_mailbox.ingress = :mandrill
   ```

3. [Configure Mandrill][mandrill-routing] to route inbound emails to `/rails/action_mailbox/mandrill/inbound_emails`.
   If your application lived at `https://example.com`, you would specify the fully-qualified URL
   `https://example.com/rails/action_mailbox/mandrill/inbound_emails`.

[mandrill-routing]: https://mandrill.zendesk.com/hc/en-us/articles/205583197-Inbound-Email-Processing-Overview

### Postfix

1. Tell Action Mailbox to accept emails from Postfix:

   ```ruby
   # config/environments/production.rb
   config.action_mailbox.ingress = :postfix
   ```

2. Generate a strong password that Action Mailbox can use to authenticate requests to the Postfix ingress.

   Use `rails credentials:edit` to add the password to your application's encrypted credentials under
   `action_mailbox.ingress_password`, where Action Mailbox will automatically find it:

   ```yaml
   action_mailbox:
     ingress_password: ...
   ```

   Alternatively, provide the password in the `RAILS_INBOUND_EMAIL_PASSWORD` environment variable.

3. [Configure Postfix][postfix-config] to pipe inbound emails to `bin/rails action_mailbox:ingress:postfix`, providing
   the `URL` of the Postfix ingress and the `INGRESS_PASSWORD` you previously generated. If your application lived at
   `https://example.com`, the full command would look like this:

   ```
   URL=https://example.com/rails/action_mailbox/postfix/inbound_emails INGRESS_PASSWORD=... bin/rails action_mailbox:ingress:postfix
   ```

[postfix-config]: https://serverfault.com/questions/258469/how-to-configure-postfix-to-pipe-all-incoming-email-to-a-script

### SendGrid

1. Tell Action Mailbox to accept emails from SendGrid:

   ```ruby
   # config/environments/production.rb
   config.action_mailbox.ingress = :sendgrid
   ```

2. Generate a strong password that Action Mailbox can use to authenticate requests to the SendGrid ingress.

   Use `rails credentials:edit` to add the password to your application's encrypted credentials under
   `action_mailbox.ingress_password`, where Action Mailbox will automatically find it:

   ```yaml
   action_mailbox:
     ingress_password: ...
   ```

   Alternatively, provide the password in the `RAILS_INBOUND_EMAIL_PASSWORD` environment variable.

3. [Configure SendGrid Inbound Parse][sendgrid-config] to forward inbound emails to
   `/rails/action_mailbox/sendgrid/inbound_emails` with the username `actionmailbox` and the password you previously
   generated. If your application lived at `https://example.com`, you would configure SendGrid with the following URL:

   ```
   https://actionmailbox:PASSWORD@example.com/rails/action_mailbox/sendgrid/inbound_emails
   ```

   **⚠️ Note:** When configuring your SendGrid Inbound Parse webhook, be sure to check the box labeled **“Post the raw,
   full MIME message.”** Action Mailbox needs the raw MIME message to work.

[sendgrid-config]: https://sendgrid.com/docs/for-developers/parsing-email/setting-up-the-inbound-parse-webhook/


## Examples

Configure basic routing:

```ruby
# app/mailboxes/application_mailbox.rb
class ApplicationMailbox < ActionMailbox::Base
  routing /^save@/i     => :forwards
  routing /@replies\./i => :replies
end
```

Then setup a mailbox:

```ruby
# Generate new mailbox
bin/rails generate mailbox forwards
```

```ruby
# app/mailboxes/forwards_mailbox.rb
class ForwardsMailbox < ApplicationMailbox
  # Callbacks specify prerequisites to processing
  before_processing :require_forward

  def process
    if forwarder.buckets.one?
      record_forward
    else
      stage_forward_and_request_more_details
    end
  end

  private
    def require_forward
      unless message.forward?
        # Use Action Mailers to bounce incoming emails back to sender – this halts processing
        bounce_with Forwards::BounceMailer.missing_forward(
          inbound_email, forwarder: forwarder
        )
      end
    end

    def forwarder
      @forwarder ||= Person.where(email_address: mail.from)
    end

    def record_forward
      forwarder.buckets.first.record \
        Forward.new forwarder: forwarder, subject: message.subject, content: mail.content
    end

    def stage_forward_and_request_more_details
      Forwards::RoutingMailer.choose_project(mail).deliver_now
    end
end
```

## Incineration of InboundEmails

By default, an InboundEmail that has been successfully processed will be incinerated after 30 days. This ensures you're not holding on to people's data willy-nilly after they may have canceled their accounts or deleted their content. The intention is that after you've processed an email, you should have extracted all the data you needed and turned it into domain models and content on your side of the application. The InboundEmail simply stays in the system for the extra time to provide debugging and forensics options.

The actual incineration is done via the `IncinerationJob` that's scheduled to run after `config.action_mailbox.incinerate_after` time. This value is by default set to `30.days`, but you can change it in your production.rb configuration. (Note that this far-future incineration scheduling relies on your job queue being able to hold jobs for that long.)


## Working with Action Mailbox in development

It's helpful to be able to test incoming emails in development without actually sending and receiving real emails. To accomplish this, there's a conductor controller mounted at `/rails/conductor/action_mailbox/inbound_emails`, which gives you an index of all the InboundEmails in the system, their state of processing, and a form to create a new InboundEmail as well.


## Testing mailboxes

Example:

```ruby
class ForwardsMailboxTest < ActionMailbox::TestCase
  test "directly recording a client forward for a forwarder and forwardee corresponding to one project" do
    assert_difference -> { people(:david).buckets.first.recordings.count } do
      receive_inbound_email_from_mail \
        to: 'save@example.com',
        from: people(:david).email_address,
        subject: "Fwd: Status update?",
        body: <<~BODY
          --- Begin forwarded message ---
          From: Frank Holland <frank@microsoft.com>

          What's the status?
        BODY
    end

    recording = people(:david).buckets.first.recordings.last
    assert_equal people(:david), recording.creator
    assert_equal "Status update?", recording.forward.subject
    assert_match "What's the status?", recording.forward.content.to_s
  end
end
```


## License

Action Mailbox is released under the [MIT License](https://opensource.org/licenses/MIT).
