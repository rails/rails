# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize objects which mixes `GlobalID::Identification`,
    # including `ActiveRecord::Base` models
    class GlobalIDSerializer < ObjectSerializer
      class << self
        def serialize(object)
          { key => object.to_global_id.to_s }
        rescue URI::GID::MissingModelIdError
          raise SerializationError, "Unable to serialize #{object.class} " \
            "without an id. (Maybe you forgot to call save?)"
        end

        def deserialize(hash)
          GlobalID::Locator.locate(hash[key])
        end

        def key
          "_aj_globalid"
        end

        private

        def klass
          GlobalID::Identification
        end
      end
    end
  end
end
