# frozen_string_literal: true

module ActiveRecord
  class Key # :nodoc:
    include Enumerable

    def self.for(name)
      case name
      when Array
        Composite.new(name)
      when nil, false
        None.new
      else
        Single.new(name)
      end
    end

    attr_reader :name, :columns

    def present?
      !@columns.empty?
    end

    def each(&block)
      @columns.each(&block)
    end

    def length
      @columns.length
    end
    alias_method :size, :length

    def to_a
      @columns
    end

    def to_s
      @name.to_s
    end

    def ==(other)
      other.is_a?(Key) && name == other.name
    end
    alias_method :eql?, :==

    def hash
      name.hash
    end

    def composite?
      raise NotImplementedError
    end

    def where_hash(values)
      raise NotImplementedError
    end

    def arel_columns(table)
      raise NotImplementedError
    end

    def cast(values, model)
      raise NotImplementedError
    end

    def value_of(record)
      raise NotImplementedError
    end

    def expects_multiple_ids?(value)
      raise NotImplementedError
    end

    def inferred_id
      raise NotImplementedError
    end

    def where_clauses(values)
      raise NotImplementedError
    end

    class Single < Key # :nodoc:
      def initialize(name)
        @name = -name.to_s
        @columns = [@name].freeze
      end

      def composite?
        false
      end

      def where_hash(values)
        { @name => values }
      end

      def arel_columns(table)
        table[@name]
      end

      def cast(value, model)
        model.type_for_attribute(@name).cast(value)
      end

      def value_of(record)
        record._read_attribute(@name)
      end

      def expects_multiple_ids?(value)
        value.is_a?(Array)
      end

      # Only composite keys have a single id to infer.
      def inferred_id
        nil
      end

      def where_clauses(values)
        [where_hash(values)]
      end
    end

    class Composite < Key # :nodoc:
      def initialize(columns)
        @columns = columns.map { |column| -column.to_s }.freeze
        @name = @columns
      end

      def composite?
        true
      end

      def where_hash(values)
        @columns.zip(values).to_h
      end

      def arel_columns(table)
        @columns.map { |column| table[column] }
      end

      def cast(values, model)
        @columns.zip(values).map! { |column, value| model.type_for_attribute(column).cast(value) }
      end

      def value_of(record)
        @columns.map { |column| record._read_attribute(column) }
      end

      # A single composite id is itself an Array, so several ids are an Array of
      # Arrays. An empty Array carries no composite id, so it is treated as an
      # empty set of ids.
      def expects_multiple_ids?(value)
        value.is_a?(Array) && (value.empty? || value.first.is_a?(Array))
      end

      # When a composite key has the conventional [tenant_key, "id"] shape,
      # associations join on "id" alone; otherwise the whole key is used.
      def inferred_id
        @columns.include?("id") ? "id" : @name
      end

      def where_clauses(values)
        values.map { |set| where_hash(set) }
      end
    end

    class None < Single # :nodoc:
      def initialize
        @name = nil
        @columns = [].freeze
      end
    end
  end
end
