# frozen_string_literal: true

module ActionController
  module Logging
    extend ActiveSupport::Concern

    module ClassMethods
      # Set a different log level per request.
      #
      #   # Use the debug log level if a particular cookie is set.
      #   class ApplicationController < ActionController::Base
      #     log_at :debug, if: -> { cookies[:debug] }
      #   end
      #
      def log_at(level, **options)
        around_action ->(_, action) { logger.log_at(level, &action) }, **options
      end
    end
  end
end
