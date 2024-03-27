# frozen_string_literal: true

gem "aws-sdk-s3"

require "aws-sdk-s3"
require "tempfile"

module ActionMailbox
  module AmazonSes
    class S3Download
      def initialize(bucket:, key:, region:)
        @bucket = bucket
        @key = key
        @region = region
      end

      def content
        Aws::S3::Client.new(region: region, access_key_id: access_key_id, secret_access_key: secret_access_key)
                       .get_object(key: key, bucket: bucket)
                       .body
                       .string
      end

      private
        attr_reader :bucket, :key, :region

        def access_key_id
          config.dig(:s3, :access_key_id)
        end

        def secret_access_key
          config.dig(:s3, :secret_access_key)
        end


        def config
          @config ||= Rails.application.config_for(:mailbox).fetch(:amazon_ses)
        end
    end
  end
end
