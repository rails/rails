module ActiveRecord #:nodoc:
  # = Active Record Serialization
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    included do
      self.include_root_in_json = true
    end

    def serializable_hash(options = nil)
      options = options.try(:clone) || {}

      options[:except] = Array(options[:except]).map { |n| n.to_s }
      options[:except] |= Array(self.class.inheritance_column)

      super(options)
    end
  end
end

require 'active_record/serializers/xml_serializer'
