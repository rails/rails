# frozen_string_literal: true

module ActiveRecord
  # Statement cache is used to cache a single statement in order to avoid creating the AST again.
  # Initializing the cache is done by passing the statement in the create block:
  #
  #   cache = StatementCache.create(ClothingItem.lease_connection) do |params|
  #     Book.where(name: "my book").where("author_id > 3")
  #   end
  #
  # The cached statement is executed by using the
  # {connection.execute}[rdoc-ref:ConnectionAdapters::DatabaseStatements#execute] method:
  #
  #   cache.execute([], ClothingItem.lease_connection)
  #
  # The relation returned by the block is cached, and for each
  # {execute}[rdoc-ref:ConnectionAdapters::DatabaseStatements#execute]
  # call the cached relation gets duped. Database is queried when +to_a+ is called on the relation.
  #
  # If you want to cache the statement without the values you can use the +bind+ method of the
  # block parameter.
  #
  #   cache = StatementCache.create(ClothingItem.lease_connection) do |params|
  #     Book.where(name: params.bind)
  #   end
  #
  # And pass the bind values as the first argument of +execute+ call.
  #
  #   cache.execute(["my book"], ClothingItem.lease_connection)
  class StatementCache # :nodoc:
    class Substitute; end # :nodoc:

    class Query # :nodoc:
      attr_reader :retryable

      def initialize(sql, retryable:)
        @sql = sql
        @retryable = retryable
      end

      def sql_for(binds, connection)
        @sql
      end
    end

    class PartialQuery < Query # :nodoc:
      def initialize(values, retryable:)
        @values = values
        @indexes = values.each_with_index.find_all { |thing, i|
          Substitute === thing
        }.map(&:last)
        @retryable = retryable
      end

      def sql_for(binds, connection)
        val = @values.dup
        @indexes.each do |i|
          value = binds.shift
          if ActiveModel::Attribute === value
            value = value.value_for_database
          end
          val[i] = connection.quote(value)
        end
        val.join
      end
    end

    class PartialQueryCollector
      attr_accessor :preparable, :retryable

      def initialize
        @parts = []
        @binds = []
      end

      def <<(str)
        @parts << str
        self
      end

      def add_bind(obj, &)
        @binds << obj
        @parts << Substitute.new
        self
      end

      def add_binds(binds, proc_for_binds = nil, &)
        @binds.concat proc_for_binds ? binds.map(&proc_for_binds) : binds
        binds.size.times do |i|
          @parts << ", " unless i == 0
          @parts << Substitute.new
        end
        self
      end

      def value
        [@parts, @binds]
      end
    end

    def self.query(...)
      Query.new(...)
    end

    def self.partial_query(...)
      PartialQuery.new(...)
    end

    def self.partial_query_collector
      PartialQueryCollector.new
    end

    class Params # :nodoc:
      def bind; Substitute.new; end
    end

    class BindMap # :nodoc:
      def initialize(bound_attributes)
        @indexes = []
        @bound_attributes = bound_attributes

        bound_attributes.each_with_index do |attr, i|
          if ActiveModel::Attribute === attr && Substitute === attr.value
            @indexes << i
          end
        end
      end

      def bind(values)
        bas = @bound_attributes.dup
        @indexes.each_with_index { |offset, i| bas[offset] = bas[offset].with_cast_value(values[i]) }
        bas
      end
    end

    def self.create(connection, callable = nil, &block)
      relation = (callable || block).call Params.new
      query_builder, binds = connection.cacheable_query(self, relation.arel)
      bind_map = BindMap.new(binds)
      new(query_builder, bind_map, relation.model)
    end

    def initialize(query_builder, bind_map, model)
      @query_builder = query_builder
      @bind_map = bind_map
      @model = model
    end

    def execute(params, connection, async: false, &block)
      bind_values = @bind_map.bind params
      sql = @query_builder.sql_for bind_values, connection

      if async
        @model.async_find_by_sql(sql, bind_values, preparable: true, allow_retry: @query_builder.retryable, &block)
      else
        @model.find_by_sql(sql, bind_values, preparable: true, allow_retry: @query_builder.retryable, &block)
      end
    rescue ::RangeError
      async ? Promise.wrap([]) : []
    end

    def self.unsupported_value?(value)
      case value
      when NilClass, Array, Range, Hash, Relation, Base then true
      end
    end
  end
end
