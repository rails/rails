require 'active_support/concern'

module ActiveJob

  # Module to be included to enable custom serialization for any object.
  module Serialization

    extend ActiveSupport::Concern

    # Instance method is just a shortcut for object serialization
    def aj_dump
      self.class.aj_dump(self).to_s
    end

    module ClassMethods

      # Return a serialized version of the argument. It must return a `#to_s` compatible object that will be
      # passed to `#load` when unserialized.
      #
      # Returns a String that will be passed to #aj_load when executing job.
      def aj_dump(value)
        raise NotImplementedError, "Implementation for #{self.class}##{__method__} must be provided"
      end

      # Used to deserialize an argument. Return value of this method will be actual argument passed to the job instance.
      def aj_load(value)
        raise NotImplementedError, "Implementation for #{self.class}##{__method__} must be provided"
      end

    end

  end

end