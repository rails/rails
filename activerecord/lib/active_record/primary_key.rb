# frozen_string_literal: true

module ActiveRecord
  # = Active Record \PrimaryKey
  #
  # Value object representing a model's primary key. It transparently handles
  # both single-column primary keys (the common case) and composite primary
  # keys made up of several columns.
  #
  # Before this abstraction existed, Active Record branched on
  # <tt>primary_key.is_a?(Array)</tt> in dozens of places to tell the two
  # apart, building <tt>where</tt> hashes, Arel references, and type casts by
  # hand each time. This object centralizes that knowledge so callers can
  # treat both kinds of key uniformly:
  #
  #   pk = model.primary_key_definition
  #   pk.composite?         # => false for "id", true for ["shop_id", "id"]
  #   pk.columns            # => always an Array of column-name Strings
  #   pk.where_hash(value)  # => conditions Hash suitable for #where
  #
  # The raw value historically returned by ActiveRecord::Base.primary_key (a
  # +String+, an +Array+, or +nil+) is still available through #name, so the
  # public API is unchanged.
  class PrimaryKey
    include Enumerable

    # The value returned by ActiveRecord::Base.primary_key:
    #
    # * a +String+ for a single-column key,
    # * a frozen +Array+ of +String+s for a composite key,
    # * +nil+ when the model has no primary key.
    attr_reader :name

    # Always a frozen +Array+ of +String+ column names. Empty when there is no
    # primary key.
    attr_reader :columns

    def initialize(name)
      if name.is_a?(Array)
        @composite = true
        @columns = name.map { |column| -column.to_s }.freeze
        @name = @columns
      elsif name
        @composite = false
        @name = -name.to_s
        @columns = [@name].freeze
      else
        @composite = false
        @name = nil
        @columns = [].freeze
      end
    end

    # Whether the primary key spans more than one column.
    def composite?
      @composite
    end

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

    # Pairs each primary key column with the matching value(s), producing a
    # Hash that can be passed straight to #where.
    #
    #   PrimaryKey.new("id").where_hash(5)
    #   # => { "id" => 5 }
    #
    #   PrimaryKey.new(["shop_id", "id"]).where_hash([1, 5])
    #   # => { "shop_id" => 1, "id" => 5 }
    def where_hash(values)
      if @composite
        @columns.zip(values).to_h
      else
        { @name => values }
      end
    end

    # Builds the Arel column reference(s) for this key against +table+.
    #
    # Returns a single Arel attribute for a simple key, or an Array of Arel
    # attributes for a composite key, matching what +compile_update+ and
    # +compile_delete+ expect.
    def arel_columns(table)
      if @composite
        @columns.map { |column| table[column] }
      else
        table[@name]
      end
    end

    # Type casts +values+ using +model+'s column types, returning a scalar for
    # a simple key and an Array of cast values for a composite key.
    def cast(values, model)
      if @composite
        @columns.zip(values).map! { |column, value| model.type_for_attribute(column).cast(value) }
      else
        model.type_for_attribute(@name).cast(values)
      end
    end

    # Reads this key's value(s) from +record+, returning a scalar for a simple
    # key and an Array of values for a composite key.
    def value_of(record)
      if @composite
        @columns.map { |column| record._read_attribute(column) }
      else
        record._read_attribute(@name)
      end
    end

    # Whether +value+ (the argument supplied to a finder such as #find)
    # represents *several* ids rather than a single one.
    #
    # For a simple key, an Array means multiple ids. For a composite key a
    # single id is *itself* an Array, so multiple ids are an Array of Arrays.
    def expects_multiple_ids?(value)
      if @composite
        value.first.is_a?(Array)
      else
        value.is_a?(Array)
      end
    end

    # When a composite key follows the conventional <tt>[tenant_key, "id"]</tt>
    # shape, associations join on "id" alone. Returns "id" when it is one of
    # the columns, otherwise the key's #name. Simple keys return their #name.
    def inferred_id
      if @composite && @columns.include?("id")
        "id"
      else
        @name
      end
    end

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
  end
end
