require 'active_job/parameters'

module ActiveJob
  module Performing
    def perform_with_hooks(*serialized_args)
      self.arguments = Parameters.deserialize(serialized_args)

      run_callbacks :perform do
        perform *arguments
      end
    end

    def perform(*)
      raise NotImplementedError
    end
  end
end
