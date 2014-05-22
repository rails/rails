require 'active_job/arguments'

module ActiveJob
  module Performing
    def perform_with_hooks(*serialized_args)
      self.arguments = Arguments.deserialize(serialized_args)

      run_callbacks :perform do
        perform *arguments
      end
    end

    def perform(*)
      raise NotImplementedError
    end
  end
end
