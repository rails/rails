# frozen_string_literal: true

module ActiveRecord
  module Querying
    delegate :find, :take, :take!, :first, :first!, :last, :last!, :exists?, :any?, :many?, :none?, :one?, to: :all
    delegate :second, :second!, :third, :third!, :fourth, :fourth!, :fifth, :fifth!, :forty_two, :forty_two!, :third_to_last, :third_to_last!, :second_to_last, :second_to_last!, to: :all
    delegate :first_or_create, :first_or_create!, :first_or_initialize, to: :all
    delegate :find_or_create_by, :find_or_create_by!, :create_or_find_by, :create_or_find_by!, :find_or_initialize_by, to: :all
    delegate :find_by, :find_by!, to: :all
    delegate :destroy_all, :delete_all, :update_all, to: :all
    delegate :find_each, :find_in_batches, :in_batches, to: :all
    delegate :select, :group, :order, :except, :reorder, :limit, :offset, :joins, :left_joins, :left_outer_joins, :or,
             :where, :rewhere, :preload, :eager_load, :includes, :from, :lock, :readonly, :extending,
             :having, :create_with, :distinct, :references, :none, :unscope, :merge, to: :all
    delegate :count, :average, :minimum, :maximum, :sum, :calculate, to: :all
    delegate :pluck, :hash_pluck, :pick, :ids, to: :all

    # Executes a custom SQL query against your database and returns all the results. The results will
    # be returned as an array with columns requested encapsulated as attributes of the model you call
    # this method from. If you call <tt>Product.find_by_sql</tt> then the results will be returned in
    # a +Product+ object with the attributes you specified in the SQL query.
    #
    # If you call a complicated SQL query which spans multiple tables the columns specified by the
    # SELECT will be attributes of the model, whether or not they are columns of the corresponding
    # table.
    #
    # The +sql+ parameter is a full SQL query as a string. It will be called as is, there will be
    # no database agnostic conversions performed. This should be a last resort because using, for example,
    # MySQL specific terms will lock you to using that particular database engine or require you to
    # change your call if you switch engines.
    #
    #   # A simple SQL query spanning multiple tables
    #   Post.find_by_sql "SELECT p.title, c.author FROM posts p, comments c WHERE p.id = c.post_id"
    #   # => [#<Post:0x36bff9c @attributes={"title"=>"Ruby Meetup", "first_name"=>"Quentin"}>, ...]
    #
    # You can use the same string replacement techniques as you can with <tt>ActiveRecord::QueryMethods#where</tt>:
    #
    #   Post.find_by_sql ["SELECT title FROM posts WHERE author = ? AND created > ?", author_id, start_date]
    #   Post.find_by_sql ["SELECT body FROM comments WHERE author = :user_id OR approved_by = :user_id", { :user_id => user_id }]
    def find_by_sql(sql, binds = [], preparable: nil, &block)
      result_set = connection.select_all(sanitize_sql(sql), "#{name} Load", binds, preparable: preparable)
      column_types = result_set.column_types.dup
      columns_hash.each_key { |k| column_types.delete k }
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
    # using the ActiveRecord::Calculations class methods. Look into those before using this.
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
