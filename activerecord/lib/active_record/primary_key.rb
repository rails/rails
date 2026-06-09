# frozen_string_literal: true

module ActiveRecord
  # = Active Record \PrimaryKey
  #
  # Represents a model's primary key. Rather than branching on
  # <tt>primary_key.is_a?(Array)</tt> throughout the codebase, the shape of the
  # key is resolved once -- when the object is built -- into one of three
  # polymorphic implementations:
  #
  # * PrimaryKey::Single    - a single-column key (the common case)
  # * PrimaryKey::Composite - a key spanning several columns
  # * PrimaryKey::None      - a model without a primary key
  #
  # Each responds to the same interface with no internal conditionals, so
  # callers never need to know which kind of key they are holding:
  #
  #   pk = model.primary_key_definition
  #   pk.composite?          # => false / true
  #   pk.columns             # => always an Array of column-name Strings
  #   pk.where_hash(value)   # => conditions Hash suitable for #where
  #   pk.arel_columns(table) # => Arel column reference(s)
  #   pk.cast(value, model)  # => type-cast id value(s)
  #
  # The raw value historically returned by ActiveRecord::Base.primary_key (a
  # +String+, an +Array+, or +nil+) is still available through #name, so the
  # public API is unchanged.
  #
  # This is an abstract base class; instantiate it through PrimaryKey.new, which
  # returns the appropriate subclass for the given key.
  class PrimaryKey
    include Enumerable

    # Builds the PrimaryKey implementation appropriate for +name+: a Composite
    # for an +Array+, None for +nil+, otherwise a Single.
    #
    # Subclasses are instantiated normally (this dispatch only kicks in when
    # +new+ is sent to PrimaryKey itself).
    def self.new(*args)
      return super unless equal?(PrimaryKey)

      case (name = args.first)
      when Array
        Composite.new(name)
      when nil, false
        None.new
      else
        Single.new(name)
      end
    end

    # The value returned by ActiveRecord::Base.primary_key:
    #
    # * a +String+ for a single-column key,
    # * a frozen +Array+ of +String+s for a composite key,
    # * +nil+ when the model has no primary key.
    attr_reader :name

    # Always a frozen +Array+ of +String+ column names. Empty when there is no
    # primary key.
    attr_reader :columns

    # Whether the model has a primary key at all.
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
      other.is_a?(PrimaryKey) && name == other.name
    end
    alias_method :eql?, :==

    def hash
      name.hash
    end

    # Whether the primary key spans more than one column.
    def composite?
      raise NotImplementedError
    end

    # Pairs the primary key column(s) with the matching value(s), producing a
    # Hash that can be passed straight to #where.
    def where_hash(values)
      raise NotImplementedError
    end

    # Builds the Arel column reference(s) for this key against +table+, as
    # expected by +compile_update+ and +compile_delete+.
    def arel_columns(table)
      raise NotImplementedError
    end

    # Type casts +values+ using +model+'s column type(s).
    def cast(values, model)
      raise NotImplementedError
    end

    # Reads this key's value(s) from +record+.
    def value_of(record)
      raise NotImplementedError
    end

    # Whether +value+ (the argument supplied to a finder such as #find)
    # represents *several* ids rather than a single one.
    def expects_multiple_ids?(value)
      raise NotImplementedError
    end

    # The primary key an association joins on when the owner has this key.
    def inferred_id
      raise NotImplementedError
    end

    # A conventional single-column primary key, e.g. "id".
    class Single < PrimaryKey
      def initialize(name)
        @name = -name.to_s
        @columns = [@name].freeze
      end

      def composite?
        false
      end

      #   Single.new("id").where_hash(5) # => { "id" => 5 }
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

      # For a simple key, an Array argument means multiple ids.
      def expects_multiple_ids?(value)
        value.is_a?(Array)
      end

      def inferred_id
        @name
      end
    end

    # A composite primary key spanning several columns, e.g. ["shop_id", "id"].
    class Composite < PrimaryKey
      def initialize(columns)
        @columns = columns.map { |column| -column.to_s }.freeze
        @name = @columns
      end

      def composite?
        true
      end

      #   Composite.new([:shop_id, :id]).where_hash([1, 5])
      #   # => { "shop_id" => 1, "id" => 5 }
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

      # A single composite id is *itself* an Array, so several ids are an Array
      # of Arrays.
      def expects_multiple_ids?(value)
        value.first.is_a?(Array)
      end

      # When a composite key follows the conventional <tt>[tenant_key, "id"]</tt>
      # shape, associations join on "id" alone; otherwise the whole key is used.
      def inferred_id
        @columns.include?("id") ? "id" : @name
      end
    end

    # Null object for a model without a primary key. It behaves like a Single
    # key whose name is +nil+, preserving the historical behavior of a +nil+
    # primary key while keeping callers free of nil checks.
    class None < Single
      def initialize
        @name = nil
        @columns = [].freeze
      end
    end
  end
end
