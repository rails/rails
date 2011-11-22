module Sprockets
  module Helpers
    module IsolatedHelper
      def controller
        nil
      end

      def config
        Rails.application.config.action_controller
      end
    end
  end
end
