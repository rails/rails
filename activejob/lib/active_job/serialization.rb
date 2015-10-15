require 'active_support/concern'

module ActiveJob
  # Module to be included to support serialization as Active Job argument for any object.
  #
  # Default implementation uses Marshal module to dump and load objects.
  #
  # In order to support argument serialization as Active Job arguments just include
  # ActiveJob::Serialization in your (Marshal compatible) type and you're ready to go.
  #
  # If your object cannot be serialized with Marshal module you must override aj_dump
  # and aj_load +class+ methods.
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
        Marshal.dump(value)
      end

      # Used to deserialize an argument. Return value of this method will be actual argument passed to the job instance.
      def aj_load(value)
        Marshal.load(value)
      end
    end
  end
end