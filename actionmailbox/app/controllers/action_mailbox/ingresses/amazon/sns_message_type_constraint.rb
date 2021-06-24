# frozen_string_literal: true

module ActionMailbox
  module Ingresses
    module Amazon
      class SnsMessageTypeConstraint
        def initialize(message_type)
          @match_message_type = message_type || "Notification"
        end

        def matches?(request)
          message_type(request) == @match_message_type
        end

        private
          def message_type(request)
            if request.content_mime_type.text?
              request.headers["X-AMZ-SNS-MESSAGE-TYPE"]
            elsif request.content_mime_type.json?
              request.params[:Type]
            end
          end
      end
    end
  end
end
