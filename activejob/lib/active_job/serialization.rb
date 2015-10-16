require 'active_support/concern'
require 'yaml'

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
    def serialize_to_job
      self.class.serialize_to_job(self).to_s
    end

    module ClassMethods
      # Return a serialized version of the argument. It must return a `#to_s` compatible object that will be
      # passed to `#load` when unserialized.
      #
      # Returns a String that will be passed to #aj_load when executing job.
      def serialize_to_job(value)
        ::YAML.dump(value)
      end

      # Used to deserialize an argument. Return value of this method will be actual argument passed to the job instance.
      #
      # Default implementation relies on +YAML.safe_load+ to avoid potential security issues. That means that
      # your class will work if it only uses basic types whitelisted by safe_load plus self and Symbol classes.
      #
      # If your ruby implementation doesn't support YAML.safe_load or you need potentially unsafe types you'll need
      # to override this method because default serialization won't work.
      def serialize_from_job(value)
        if ::YAML.respond_to?(:safe_load)
          # Allow this class and symbols deserialization. If this raises a Psych::DisallowedClass it will be wrapped
          # in an ActiveJob::DeserializationError instance giving user a proper error message.
          ::YAML.safe_load(value, [self, Symbol])
        else
          raise NotImplementedError, 'To use automatic unserialization your YAML library must support #safe_load'
        end
      end
    end
  end
end