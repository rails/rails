# frozen_string_literal: true

module ActiveRecord
  class Key # :nodoc:
    def self.for(name)
      key = case name
      when Array
        Composite.new(name)
      when nil, false
        None.new
      else
        Single.new(name)
      end

      key.freeze
    end

    attr_reader :name, :columns

    def present?
      true
    end

    delegate :each, :index_with, to: :@columns

    def all?(...) = @columns.all?(...)
    def any?(...) = @columns.any?(...)
    def none?(...) = @columns.none?(...)
    def count(...) = @columns.count(...)
    def map(&) = @columns.map(&)
    def each_with_index(&) = @columns.each_with_index(&)

    def length
      @columns.length
    end
    alias_method :size, :length

    def [](index)
      @columns[index]
    end

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

    # Yields column names and returns a scalar or tuple according to the key's
    # shape. Unlike Enumerable#map, a scalar result is not wrapped in an Array.
    def map_value
      raise NotImplementedError
    end

    # Reads attributes with optional per-column normalizers. A nil list or entry
    # leaves the corresponding values unchanged. Columns are declared names,
    # resolved through the record's attribute aliases.
    def value_of(record, normalizers = nil)
      raise NotImplementedError
    end

    # Like #value_of, but columns must already be physical attribute names
    # for the record's class; aliases are not resolved again.
    def _value_of(record, normalizers = nil)
      raise NotImplementedError
    end

    def expects_multiple_ids?(value)
      raise NotImplementedError
    end

    def inferred_id
      raise NotImplementedError
    end

    def inferred_key
      raise NotImplementedError
    end

    def where_clauses(values)
      raise NotImplementedError
    end

    def include?(column)
      raise NotImplementedError
    end

    # Returns true if every column of this key is also a column of `other`.
    def subset?(other)
      raise NotImplementedError
    end

    # Returns this key with each column resolved through the aliases of
    # `owner`, a model or record, or self when no column is aliased.
    def resolve_aliases(owner)
      raise NotImplementedError
    end

    class Single < Key # :nodoc:
      def initialize(name)
        @name = name.is_a?(Symbol) ? name.name : -name.to_s
        @columns = [@name].freeze
      end

      def each
        return super unless block_given?
        yield @name
        self
      end

      def all?(pattern = (no_pattern = true))
        return super(pattern) unless no_pattern
        return super() unless block_given?
        yield(@name) ? true : false
      end

      def any?(pattern = (no_pattern = true))
        return super(pattern) unless no_pattern
        return super() unless block_given?
        yield(@name) ? true : false
      end

      def none?(pattern = (no_pattern = true))
        return super(pattern) unless no_pattern
        return super() unless block_given?
        yield(@name) ? false : true
      end

      def each_with_index
        return super unless block_given?
        yield @name, 0
        @columns
      end

      def map
        return super unless block_given?
        [yield(@name)]
      end

      def zip(other)
        return [[@name, other[0]]] unless block_given?
        yield @name, other[0]
        nil
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

      def map_value
        return enum_for(:map_value) unless block_given?
        yield @name
      end

      def value_of(record, normalizers = nil)
        value = record.read_attr(@name)
        normalizer = normalizers&.first
        normalizer ? normalizer.call(value) : value
      end

      def _value_of(record, normalizers = nil)
        value = record._read_attribute(@name)
        normalizer = normalizers&.first
        normalizer ? normalizer.call(value) : value
      end

      def expects_multiple_ids?(value)
        value.is_a?(Array)
      end

      # Only composite keys have a single id to infer.
      def inferred_id
        nil
      end

      def inferred_key
        nil
      end

      def where_clauses(values)
        [where_hash(values)]
      end

      def include?(column)
        @name == column
      end

      def subset?(other)
        other.include?(@name)
      end

      def resolve_aliases(owner)
        aliaz = owner.resolve_alias(@name)

        if aliaz == @name
          self
        else
          Key.for(aliaz)
        end
      end
    end

    class Composite < Key # :nodoc:
      def initialize(columns)
        @columns = columns.map { |column| -column.to_s }.freeze
        @name = @columns
        @inferred_key = @columns.include?("id") ? Single.new("id").freeze : self
      end

      def zip(other, &)
        @columns.zip(other.to_a, &)
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
        casted = []
        @columns.zip(values) do |column, value|
          casted << model.type_for_attribute(column).cast(value)
        end
        casted
      end

      def map_value(&)
        @columns.map(&)
      end

      def value_of(record, normalizers = nil)
        if normalizers
          Array.new(@columns.length) do |index|
            value = record.read_attr(@columns[index])
            normalizer = normalizers[index]
            normalizer ? normalizer.call(value) : value
          end
        else
          @columns.map { |column| record.read_attr(column) }
        end
      end

      def _value_of(record, normalizers = nil)
        if normalizers
          Array.new(@columns.length) do |index|
            value = record._read_attribute(@columns[index])
            normalizer = normalizers[index]
            normalizer ? normalizer.call(value) : value
          end
        else
          @columns.map { |column| record._read_attribute(column) }
        end
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
        @inferred_key.name
      end

      # The Key form of `inferred_id`.
      attr_reader :inferred_key

      def where_clauses(values)
        values.map { |set| where_hash(set) }
      end

      def include?(column)
        @columns.include?(column)
      end

      def subset?(other)
        @columns.all? { |column| other.include?(column) }
      end

      def resolve_aliases(owner)
        if @columns.any? { |name| owner.resolve_alias(name) != name }
          Key.for(@columns.map { |n| owner.resolve_alias(n) })
        else
          self
        end
      end
    end

    class None < Single # :nodoc:
      EMPTY = [].freeze

      def initialize
        @name = nil
        @columns = EMPTY
      end

      def present?
        false
      end

      def include?(column)
        false
      end

      # The empty set is a subset of every key.
      def subset?(other)
        true
      end

      def each(&block)
        return enum_for(:each) unless block
        self
      end

      def all?(...) = EMPTY.all?(...)
      def any?(...) = EMPTY.any?(...)
      def none?(...) = EMPTY.none?(...)
      def map(...) = EMPTY.map(...)
      def each_with_index(&) = EMPTY.each_with_index(&)

      def zip(other, &)
        EMPTY.zip(other.to_a, &)
      end

      def map_value
        return enum_for(:map_value) unless block_given?
        nil
      end

      def _value_of(record, normalizers = nil)
        nil
      end
    end

    # An ordered correspondence between two database keys.
    class Mapping # :nodoc:
      include Enumerable

      attr_reader :reference_key, :target_key

      def self.empty
        EMPTY
      end

      def initialize(reference_key:, target_key:)
        @reference_key = reference_key
        @target_key = target_key
        if @reference_key.length != @target_key.length
          raise ArgumentError, "Key mappings must have the same number of columns"
        end
        @pairs = @reference_key.zip(@target_key).map!(&:freeze).freeze
        @hash = [@reference_key, @target_key].hash
        freeze
      end

      def each(&block)
        @pairs.each(&block)
      end

      def empty?
        @pairs.empty?
      end

      # Returns an equivalent mapping with single-column composite keys
      # converted to scalar keys.
      def normalize
        return self unless @reference_key.length == 1 && (@reference_key.composite? || @target_key.composite?)

        self.class.new(
          reference_key: @reference_key.composite? ? Key.for(@reference_key.columns.first) : @reference_key,
          target_key: @target_key.composite? ? Key.for(@target_key.columns.first) : @target_key
        )
      end

      def +(other)
        return other if empty?
        return self if other.empty?

        self.class.new(
          reference_key: Key.for([*@reference_key, *other.reference_key]),
          target_key: Key.for([*@target_key, *other.target_key])
        )
      end

      def ==(other)
        other.is_a?(Mapping) &&
          reference_key == other.reference_key &&
          target_key == other.target_key
      end
      alias_method :eql?, :==

      attr_reader :hash

      EMPTY = begin
        key = Key.for(nil)
        new(reference_key: key, target_key: key)
      end
      private_constant :EMPTY
    end
  end
end
