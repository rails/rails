require 'active_support/json'
require 'active_support/core_ext/class/attribute_accessors'

module ActiveModel
  module Serializers
    module JSON
      extend ActiveSupport::Concern
      include ActiveModel::Attributes

      included do
        extend ActiveModel::Naming

        cattr_accessor :include_root_in_json, :instance_writer => false
      end

      class Serializer < ActiveModel::Serializer
        def serializable_hash
          model = super
          if @serializable.include_root_in_json
            model = { @serializable.class.model_name.element => model }
          end
          model
        end

        def serialize
          ActiveSupport::JSON.encode(serializable_hash)
        end
      end

      def encode_json(encoder)
        Serializer.new(self, encoder.options).to_s
      end

      def as_json(options = nil)
        self
      end

      def from_json(json)
        self.attributes = ActiveSupport::JSON.decode(json)
        self
      end
    end
  end
end
