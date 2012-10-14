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

    private
      # Additional options can be provided for associations specified via the <tt>:include</tt> option.
      #
      # You can respond with included collections like this:
      #
      #   respond_with @authors, include: [books: { order: "price ASC", limit: 5, where: ["price < ?", 5] }]
      def fetch_query_methods(records, opts)
        limit = opts.fetch(:limit, nil)
        order = opts.fetch(:order, nil)
        where = opts.fetch(:where, nil)

        records = records.limit(limit) if limit && records.respond_to?(:limit)
        records = records.order(order) if order && records.respond_to?(:order)
        records = records.where(where) if where && records.respond_to?(:where)
        records
      end
  end
end

require 'active_record/serializers/xml_serializer'
