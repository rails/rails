require 'active_support/rescuable'
require 'active_job/arguments'

module ActiveJob
  module Performing
    extend ActiveSupport::Concern
    
    included do
      include ActiveSupport::Rescuable
    end

    def perform_with_hooks(*serialized_args)
      self.arguments = Arguments.deserialize(serialized_args)

      run_callbacks :perform do
        perform *arguments
      end
    rescue => exception
      rescue_with_handler(exception)
    end

    def perform(*)
      raise NotImplementedError
    end
  end
end
