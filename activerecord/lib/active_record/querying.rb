# frozen_string_literal: true

module ActiveRecord
  module Querying
    QUERYING_METHODS = [
      :find, :find_by, :find_by!, :take, :take!, :sole, :find_sole_by, :first, :first!, :last, :last!,
      :second, :second!, :third, :third!, :fourth, :fourth!, :fifth, :fifth!,
      :forty_two, :forty_two!, :third_to_last, :third_to_last!, :second_to_last, :second_to_last!,
      :exists?, :any?, :many?, :none?, :one?,
      :first_or_create, :first_or_create!, :first_or_initialize,
      :find_or_create_by, :find_or_create_by!, :find_or_initialize_by,
      :create_or_find_by, :create_or_find_by!,
      :destroy_all, :delete_all, :update_all, :touch_all, :destroy_by, :delete_by,
      :find_each, :find_in_batches, :in_batches,
      :select, :reselect, :order, :reorder, :group, :limit, :offset, :joins, :left_joins, :left_outer_joins,
      :where, :rewhere, :invert_where, :preload, :extract_associated, :eager_load, :includes, :from, :lock, :readonly,
      :and, :or, :annotate, :optimizer_hints, :extending,
      :having, :create_with, :distinct, :references, :none, :unscope, :merge, :except, :only,
      :count, :average, :minimum, :maximum, :sum, :calculate,
      :pluck, :pick, :ids, :strict_loading, :excluding
    ].freeze # :nodoc:
    delegate(*QUERYING_METHODS, to: :all)

    # Executes a custom SQL query against your database and returns all the results. The results will
    # be returned as an array, with the requested columns encapsulated as attributes of the model you call
    # this method from. For example, if you call <tt>Product.find_by_sql</tt>, then the results will be returned in
    # a +Product+ object with the attributes you specified in the SQL query.
    #
    # If you call a complicated SQL query which spans multiple tables, the columns specified by the
    # SELECT will be attributes of the model, whether or not they are columns of the corresponding
    # table.
    #
    # The +sql+ parameter is a full SQL query as a string. It will be called as is; there will be
    # no database agnostic conversions performed. This should be a last resort because using
    # database-specific terms will lock you into using that particular database engine, or require you to
    # change your call if you switch engines.
    #
    #   # A simple SQL query spanning multiple tables
    #   Post.find_by_sql "SELECT p.title, c.author FROM posts p, comments c WHERE p.id = c.post_id"
    #   # => [#<Post:0x36bff9c @attributes={"title"=>"Ruby Meetup", "author"=>"Quentin"}>, ...]
    #
    # You can use the same string replacement techniques as you can with <tt>ActiveRecord::QueryMethods#where</tt>:
    #
    #   Post.find_by_sql ["SELECT title FROM posts WHERE author = ? AND created > ?", author_id, start_date]
    #   Post.find_by_sql ["SELECT body FROM comments WHERE author = :user_id OR approved_by = :user_id", { :user_id => user_id }]
    def find_by_sql(sql, binds = [], preparable: nil, &block)
      _load_from_sql(_query_by_sql(sql, binds, preparable: preparable), &block)
    end

    def _query_by_sql(sql, binds = [], preparable: nil, async: false) # :nodoc:
      connection.select_all(sanitize_sql(sql), "#{name} Load", binds, preparable: preparable, async: async)
    end

    def _load_from_sql(result_set, &block) # :nodoc:
      column_types = result_set.column_types

      unless column_types.empty?
        column_types = column_types.reject { |k, _| attribute_types.key?(k) }
      end

      message_bus = ActiveSupport::Notifications.instrumenter

      payload = {
        record_count: result_set.length,
        class_name: name
      }

      message_bus.instrument("instantiation.active_record", payload) do
        if result_set.includes_column?(inheritance_column)
          result_set.map { |record| instantiate(record, column_types, &block) }
        else
          # Instantiate a homogeneous set
          result_set.map { |record| instantiate_instance_of(self, record, column_types, &block) }
        end
      end
    end

    # Returns the result of an SQL statement that should only include a COUNT(*) in the SELECT part.
    # The use of this method should be restricted to complicated SQL queries that can't be executed
    # using the ActiveRecord::Calculations class methods. Look into those before using this method,
    # as it could lock you into a specific database engine or require a code change to switch
    # database engines.
    #
    #   Product.count_by_sql "SELECT COUNT(*) FROM sales s, customers c WHERE s.customer_id = c.id"
    #   # => 12
    #
    # ==== Parameters
    #
    # * +sql+ - An SQL statement which should return a count query from the database, see the example above.
    def count_by_sql(sql)
      connection.select_value(sanitize_sql(sql), "#{name} Count").to_i
    end
  end
end
