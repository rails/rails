module ActiveRecord #:nodoc:
  # = Active Record Serialization
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    def serializable_hash(options = nil)
      options = options.try(:clone) || {}

      options[:except] = Array.wrap(options[:except]).map { |n| n.to_s }
      options[:except] |= Array.wrap(self.class.inheritance_column)

      super(options)
    end
  end
end

require 'active_record/serializers/xml_serializer'
