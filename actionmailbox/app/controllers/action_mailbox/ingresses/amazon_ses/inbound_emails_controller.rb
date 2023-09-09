# frozen_string_literal: true

module ActionMailbox
  module Ingresses
    # Ingests inbound emails from Amazon SES/SNS and confirms subscriptions.
    #
    # Subscription requests must provide the following parameters in a JSON body:
    # - +Message+: Notification content
    # - +MessageId+: Notification unique identifier
    # - +Timestamp+: iso8601 timestamp
    # - +TopicArn+: Topic identifier
    # - +Type+: Type of event ("SubscriptionConfirmation")
    #
    # Inbound email events must provide the following parameters in a JSON body:
    # - +Message+: Notification content
    # - +MessageId+: Notification unique identifier
    # - +Timestamp+: iso8601 timestamp
    # - +TopicArn+: Topic identifier
    # - +Type+: Type of event ("Notification")
    #
    # All requests are authenticated by validating the provided AWS signature.
    #
    # Returns:
    #
    # - <tt>204 No Content</tt> if a request is successfully processed
    # - <tt>401 Unauthorized</tt> if a request does not contain a valid signature
    # - <tt>404 Not Found</tt> if the Amazon ingress has not been configured
    # - <tt>422 Unprocessable Entity</tt> if a request provides invalid parameters
    #
    # == Usage
    #
    # 1. {Configure SES}[https://docs.aws.amazon.com/ses/latest/DeveloperGuide/receiving-email-notifications.html] to (save emails to S3)[https://docs.aws.amazon.com/ses/latest/dg/receiving-email-action-s3.html].
    #
    #    Select the option to also trigger notification in SNS.
    #
    #    Take note of the topic unique reference (+TopicArn+) when using/creating the SNS topic.
    #
    #    {Configure the SNS topic}[https://docs.aws.amazon.com/ses/latest/DeveloperGuide/receiving-email-action-sns.html] to send notifications to +/rails/action_mailbox/amazon_ses/inbound_emails+.
    #    The option "Enable raw message delivery" must not be selected. See {documentation}[https://docs.aws.amazon.com/sns/latest/dg/sns-large-payload-raw-message-delivery.html] for more details.
    #
    #    If your application is found at <tt>https://example.com</tt> you would specify the fully-qualified URL <tt>https://example.com/rails/action_mailbox/amazon_ses/inbound_emails</tt>.
    #
    # 2. Add the +aws-sdk-sns+ and +aws-sdk-s3+ gems to your Gemfile.
    #
    # 3. Configure Action Mailbox to accept notifications from Amazon SES:
    #
    #        # config/environments/production.rb
    #        config.action_mailbox.ingress = :amazon_ses
    #
    # 4. Configure which SNS topics will be accepted:
    #
    #        # config/mailbox.yml
    #        development:
    #        amazon_ses:
    #          subscribed_topics:
    #          - arn:aws:sns:eu-west-1:123456789001:example-topic-1
    #          - arn:aws:sns:us-east-1:123456789002:example-topic-2
    #          # Optionally include S3 credentials, otherwise use default `aws-sdk-s3` credential discovery.
    #          # See https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html for details.
    #          s3:
    #           access_key_id: ABC123DEF456
    #           secret_access_key: ZYXCBA987543210
    #
    # Your application is now ready to accept confirmation requests and email notifications.
    #
    # To test, follow the {ActionMailbox setup guide}[https://guides.rubyonrails.org/action_mailbox_basics.html], then send an email to your inbound email address configured in _SES_ and inspect +ActionMailbox::InboundEmail.last+.
    #
    # If the email was routed successfully it will be available for inspection.
    #
    module AmazonSes
      class InboundEmailsController < BaseController
        rescue_from "SnsNotification::MessageContentError" do
          head :bad_request
        end

        def create
          ActionMailbox::InboundEmail.create_and_extract_message_id! @notification.message_content
        end
      end
    end
  end
end
