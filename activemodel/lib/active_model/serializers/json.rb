require 'active_support/json'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'

module ActiveModel
  module Serializers
    module JSON
      extend ActiveSupport::Concern
      include ActiveModel::Attributes

      included do
        cattr_accessor :include_root_in_json, :instance_writer => false
      end

      def encode_json(encoder)
        options = encoder.options || {}

        hash = if options[:only]
          only = Array.wrap(options[:only]).map { |attr| attr.to_s }
          attributes.slice(*only)
        elsif options[:except]
          except = Array.wrap(options[:except]).map { |attr| attr.to_s }
          attributes.except(*except)
        else
          attributes
        end

        hash = { self.class.model_name.element => hash } if include_root_in_json
        ActiveSupport::JSON.encode(hash)
      end

      def as_json(options = nil)
        self
      end
    end
  end
end
