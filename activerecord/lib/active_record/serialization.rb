module ActiveRecord #:nodoc:
  # = Active Record \Serialization
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    included do
      self.include_root_in_json = false
    end

    def serializable_hash(options = nil)
      options = options.try(:dup) || {}

      options[:except] = Array(options[:except]).map(&:to_s)
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
