# frozen_string_literal: true

require "tempfile"

module ActionMailbox
  module Ingresses
    module Amazon
      class SnsNotification
        def initialize(params)
          @params = params
        end

        def subscription_confirmed?
          confirmation_response.code&.start_with?("2")
        end

        def verified?
          require "aws-sdk-sns"
          Aws::SNS::MessageVerifier.new.authentic?(params.to_json)
        end

        def topic
          params[:TopicArn]
        end

        # This needs to be the raw email message
        def message_content
          if receipt?
            # Assume you want emails greater than 150k an possibly an atatchment,
            # so you will be using S3 to store the raw email and we have to go get it
            action = message.dig(:receipt, :action)

            if action[:type] == "S3"
              read_content_from_s3(action)
            else
              message["content"]
            end

          end
        end

        def no_content?
          if receipt? && (content_in_s3? || !message["content"].blank?)
            false
          else
            true
          end
        end

        private
          attr_reader :params

          def content_in_s3?
            message.dig(:receipt, :action, :type) == "S3"
          end

          def read_content_from_s3(action)
            require "aws-sdk-s3"

            bucket_name = action[:bucketName]
            object_key = action[:objectKey]
            guess_region = action[:topicArn].split(":")[3]
            s3 = Aws::S3::Resource.new(region: guess_region)
            obj = s3.bucket(bucket_name).object(object_key)
            begin
              temp = Tempfile.new
              obj.download_file(temp.path)
              contents = temp.open.read
              contents
            ensure
              temp.close
              temp.unlink
            end
          end

          def message
            @message ||= JSON.parse(params[:Message]).with_indifferent_access
          end

          def receipt?
            params[:Type] == "Notification" && message["notificationType"] == "Received"
          end

          def confirmation_response
            @confirmation_response ||= Net::HTTP.get_response(URI(params[:SubscribeURL]))
          end
      end
    end
  end
end
