module ActiveRecord #:nodoc:
  ActiveSupport.on_load(:active_record_config) do
    mattr_accessor :include_root_in_json, instance_accessor: false
    self.include_root_in_json = true
  end

  # = Active Record Serialization
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    included do
      singleton_class.class_eval do
        remove_method :include_root_in_json
        delegate :include_root_in_json, to: 'ActiveRecord::Model'
      end
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
