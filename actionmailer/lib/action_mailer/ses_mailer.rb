# frozen_string_literal: true

gem "aws-sdk-ses", "~> 1"

require "aws-sdk-ses"

module ActionMailer
  module DeliveryMethods
    # Provides a delivery method for ActionMailer that uses Amazon Simple
    # Email Service. This uses the AWS SDK for Ruby's credential provider
    # chain when creating an SES client instance. SES can also be used with
    # Mail::SMTP but only with static credentials.
    class SESMailer
      # @param [Hash] options Passes along initialization options to
      #   [Aws::SES::Client.new](http://docs.aws.amazon.com/sdkforruby/api/Aws/SES/Client.html#initialize-instance_method).
      def initialize(options = {})
        @client = Aws::SES::Client.new(options)
      end

      # Rails expects this method to exist, and to handle a Mail::Message
      # object correctly. Called during mail delivery.
      def deliver!(message)
        send_opts = {}
        send_opts[:raw_message] = {}
        send_opts[:raw_message][:data] = message.to_s

        if message.respond_to?(:destinations)
          send_opts[:destinations] = message.destinations
        end

        @client.send_raw_email(send_opts).tap do |response|
          message.header[:ses_message_id] = response.message_id
        end
      end

      # ActionMailer expects this method to be present and to return a hash.
      def settings
        {}
      end
    end
  end
end
