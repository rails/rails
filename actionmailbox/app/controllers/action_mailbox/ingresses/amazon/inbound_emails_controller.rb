# frozen_string_literal: true

module ActionMailbox
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
  # 1. {Configure SES}[https://docs.aws.amazon.com/ses/latest/DeveloperGuide/receiving-email-notifications.html] to route emails through SNS. Take note of the topic unique reference (+TopicArn+).
  #    The option "Enable raw message delivery" should not be selected. See {documentation}[https://docs.aws.amazon.com/sns/latest/dg/sns-large-payload-raw-message-delivery.html] for more details.
  #
  #    {Configure SNS}[https://docs.aws.amazon.com/ses/latest/DeveloperGuide/receiving-email-action-sns.html] to send notifications to +/rails/action_mailbox/amazon/inbound_emails+.
  #
  #    If your application is found at <tt>https://example.com</tt> you would specify the fully-qualified URL <tt>https://example.com/rails/action_mailbox/amazon/inbound_emails</tt>.
  #
  # 2. Install the {aws-sdk-sns}[https://rubygems.org/gems/aws-sdk-sns] gem:
  #
  #        # Gemfile
  #        gem "aws-sdk-sns", "~> 1.9", require: false
  #
  # 3. Tell Action Mailbox to accept notifications from Amazon:
  #
  #        # config/environments/production.rb
  #        config.action_mailbox.ingress = :amazon
  #
  # 4. Configure which SNS topics will be accepted:
  #
  #        config.action_mailbox.amazon.subscribed_topics = %w(
  #          arn:aws:sns:eu-west-1:123456789001:example-topic-1
  #          arn:aws:sns:us-east-1:123456789002:example-topic-2
  #        )
  #
  # Your application is now ready to accept confirmation requests and email notifications.
  #
  module Ingresses
    module Amazon
      class InboundEmailsController < BaseController
        before_action :ensure_message_content

        def create
          ActionMailbox::InboundEmail.create_and_extract_message_id! @notification.message_content
        end

        private
          def ensure_message_content
            head :bad_request if @notification.no_content?
          end
      end
    end
  end
end
