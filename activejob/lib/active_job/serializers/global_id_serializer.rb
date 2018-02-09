# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize objects which mixes `GlobalID::Identification`,
    # including `ActiveRecord::Base` models
    class GlobalIDSerializer < BaseSerializer # :nodoc:
      def serialize(object)
        { GLOBALID_KEY => object.to_global_id.to_s }
      rescue URI::GID::MissingModelIdError
        raise SerializationError, "Unable to serialize #{object.class} " \
          "without an id. (Maybe you forgot to call save?)"
      end

      def deserialize(hash)
        GlobalID::Locator.locate(hash[GLOBALID_KEY])
      end

      def deserialize?(argument)
        argument.is_a?(Hash) && argument[GLOBALID_KEY]
      end

      private

        def klass
          GlobalID::Identification
        end
    end
  end
end
