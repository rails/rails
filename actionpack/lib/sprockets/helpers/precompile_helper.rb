module Sprockets
  module Helpers
    module PrecompileHelper
      def controller
        nil
      end

      def config
        Rails.application.config.action_controller
      end
    end
  end
end
