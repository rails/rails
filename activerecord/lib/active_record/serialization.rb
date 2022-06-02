# frozen_string_literal: true

module ActiveRecord # :nodoc:
  # = Active Record \Serialization
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    included do
      self.include_root_in_json = false
    end

    def serializable_hash(options = nil)
      if self.class._has_attribute?(self.class.inheritance_column)
        options = options ? options.dup : {}

        options[:except] = Array(options[:except]).map(&:to_s)
        options[:except] |= Array(self.class.inheritance_column)
      end

      super(options)
    end

    private
      def attribute_names_for_serialization
        attribute_names
      end
  end
end
