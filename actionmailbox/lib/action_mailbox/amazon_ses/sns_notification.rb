# frozen_string_literal: true

gem "aws-sdk-sns"

require "aws-sdk-sns"
require "action_mailbox/amazon_ses/s3_download"

module ActionMailbox
  module AmazonSes
    class SnsNotification
      class MessageContentError < StandardError; end

      def initialize(request_body)
        @request_body = request_body
      end

      def subscription_confirmed?
        confirmation_response.code&.start_with?("2")
      end

      def verified?
        Aws::SNS::MessageVerifier.new.authentic?(@request_body)
      end

      def topic
        notification.fetch(:TopicArn)
      end

      def message_content
        return S3Download.new(bucket: bucket, key: key, region: region).content if receipt? && content_in_s3?

        raise MessageContentError, "Incoming emails must have notificationType `Received` and must be stored to S3"
      end

      private
        def notification
          @notification ||= JSON.parse(@request_body, symbolize_names: true)
        rescue JSON::ParserError => e
          Rails.logger.warn("Unable to parse SNS notification: #{e}")
          nil
        end

        def message
          @message ||= JSON.parse(notification[:Message], symbolize_names: true)
        end

        def action
          message.fetch(:receipt).fetch(:action)
        end

        def bucket
          action.fetch(:bucketName)
        end

        def region
          action.fetch(:topicArn).split(":")[3]
        end

        def key
          action.fetch(:objectKey)
        end

        def content_in_s3?
          action.fetch(:type) == "S3"
        end

        def receipt?
          message.fetch(:notificationType) == "Received"
        end

        def confirmation_response
          @confirmation_response ||= Net::HTTP.get_response(URI(notification[:SubscribeURL]))
        end
    end
  end
end
