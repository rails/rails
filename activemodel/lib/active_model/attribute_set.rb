# frozen_string_literal: true

# :markup: markdown
require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/deep_dup"
require "active_model/attribute_set/builder"
require "active_model/attribute_set/yaml_encoder"

module ActiveModel
  # +attributes+ is an IndexedRow of Attribute objects.
  class ReadOnlyAttributeSet # :nodoc:
    delegate :each_value, :fetch, :except, :indexes, to: :attributes

    def initialize(attributes)
      @attributes = attributes
      raise ArgumentError, "all attributes should be initialized" unless all_initialized?
      freeze
    end

    def [](name)
      @attributes[name] || default_attribute(name)
    end

    def cast_types
      attributes.transform_values(&:type)
    end

    def keys
      attributes.keys
    end

    def key?(name)
      attributes.key?(name)
    end
    alias :include? :key?

    def values
      attributes.values
    end

    #: () -> ActiveModel::AttributeSet
    def writable
      AttributeSet.new(attributes.transform_row(&:dup))
    end

    def to_hash
      keys.index_with { |name| self[name].value }
    end

    alias :to_h :to_hash

    #: () { (ActiveModel::Attribute) -> ActiveModel::Attribute } -> instance
    def map(&block)
      new_attributes = attributes.transform_row(&block)
      self.class.new(new_attributes)
    end

    #: () -> instance
    def deep_dup
      self.class.new(attributes.transform_row(&:deep_dup))
    end

    def ==(other)
      other.class == self.class && attributes == other.attributes
    end

    def read_only?
      true
    end

    attr_reader :attributes

    private
      def all_initialized?
        attributes.values.all? { |v| v.initialized? }
      end

      def default_attribute(name)
        Attribute.null(name)
      end
  end

  # +attributes+ is an IndexedRow::Mutable of Attribute objects.
  class AttributeSet # :nodoc:
    delegate :each_value, :fetch, :except, to: :attributes

    def initialize(attributes)
      @attributes = attributes
    end

    #: () -> (Hash[String, Integer] | ActiveModel::IndexedRow::ExtendedIndexes)
    def indexes
      attributes.indexes
    end

    def read_only
      attributes.values.each(&:freeze)
      attributes.freeze
      ReadOnlyAttributeSet.new(attributes)
    end

    #: (String) -> ActiveModel::Attribute
    def [](name)
      lookup(name) || default_attribute(name)
    end

    #: (String, ActiveModel::Attribute) -> ActiveModel::Attribute
    def []=(name, value)
      store(name, value)
    end

    def cast_types
      attributes.transform_values(&:type)
    end

    def values_before_type_cast
      attributes.transform_values(&:value_before_type_cast)
    end

    def values_for_database
      attributes.transform_values(&:value_for_database)
    end

    def to_hash
      keys.index_with { |name| self[name].value }
    end
    alias :to_h :to_hash

    def key?(name)
      attributes.key?(name) && self[name].initialized?
    end
    alias :include? :key?

    def keys
      attributes.each_key.select { |name| self[name].initialized? }
    end

    def fetch_value(name, &block)
      self[name].value(&block)
    end

    # Like #fetch_value, but raises MissingAttributeError if the attribute is
    # uninitialized.
    def fetch_value!(name)
      self[name].value!
    end

    # Like #fetch_value, but looks the attribute up by its +index+ in
    # #indexes rather than by name. Returns +nil+ for a missing attribute,
    # as Attribute::Null does.
    #: (Integer) ?{ (String) -> untyped } -> untyped
    def fetch_value_at(index, &block)
      attributes.at(index)&.value(&block)
    end

    # Like #fetch_value!, but looks the attribute up by its +index+ (see
    # #fetch_value_at).
    #: (Integer) -> untyped
    def fetch_value_at!(index)
      attributes.at(index)&.value!
    end

    # The name of the attribute at +index+. Searches #indexes, so it's for
    # error messages rather than the read path.
    #: (Integer) -> String?
    def name_at(index)
      indexes.each_key.find { |name| indexes[name] == index }
    end

    #: (String, untyped) -> ActiveModel::Attribute
    def write_from_database(name, value)
      store(name, self[name].with_value_from_database(value))
    end

    #: (String, untyped) -> untyped
    def write_from_user(name, value)
      raise FrozenError, "can't modify frozen attributes" if frozen?
      store(name, self[name].with_value_from_user(value))
      value
    end

    #: (String, untyped) -> ActiveModel::Attribute
    def write_cast_value(name, value)
      store(name, self[name].with_cast_value(value))
    end

    #: () -> self
    def freeze
      freeze_attributes
      super
    end

    #: () -> ActiveModel::AttributeSet
    def deep_dup
      AttributeSet.new(attributes.transform_row(&:dup_or_share))
    end

    def initialize_dup(_)
      @attributes = @attributes.dup
      super
    end

    def initialize_clone(...)
      @attributes = @attributes.clone
      super
    end

    def reset(key)
      if key?(key)
        write_from_database(key, nil)
      end
    end

    def accessed
      attributes.each_key.select { |name| self[name].has_been_read? }
    end

    #: () { (ActiveModel::Attribute) -> ActiveModel::Attribute } -> ActiveModel::AttributeSet
    def map(&block)
      new_attributes = attributes.transform_row(&block)
      AttributeSet.new(new_attributes)
    end

    def values
      attributes.values
    end

    def ==(other)
      other.class == self.class && attributes == other.attributes
    end

    def read_only?
      false
    end

    protected
      attr_reader :attributes

    private
      #: (String) -> ActiveModel::Attribute?
      def lookup(name)
        @attributes[name]
      end

      #: (String, ActiveModel::Attribute) -> ActiveModel::Attribute
      def store(name, attribute)
        @attributes[name] = attribute
      end

      #: () -> void
      def freeze_attributes
        attributes.freeze
      end

      def default_attribute(name)
        Attribute.null(name)
      end
  end

  # Attributes are cached in a plain Array, by the index of the attribute's
  # name in +indexes+, which cover every attribute of the model plus any
  # extra columns (such as aliases) the row was loaded with.
  # Methods that take a name look its index up once and work by index from
  # there.
  class LazyIndexedAttributeSet < AttributeSet # :nodoc:
    # Marks the slots in +@casted_values+ that haven't been cast yet, since
    # a value can be cast to +nil+.
    UNCAST = Object.new.freeze
    private_constant :UNCAST

    attr_reader :indexes

    # +row+ is the raw data from the database, an Array laid out by
    # +indexes+ (see IndexedRow), which also type any names the model
    # doesn't have (like from `select count(*) as blah`). +ctx+ is a
    # Builder::Context, for looking up the model's attributes by index.
    #: (Array[untyped], Hash[String, Integer] | ActiveModel::IndexedRow::ExtendedIndexes, ActiveModel::AttributeSet::Builder::Context) -> void
    def initialize(row, indexes, ctx)
      # Attributes are only built when something needs one (a write, a
      # default, or #materialize), so +@attributes+ starts out +nil+.
      super(nil)
      @row = row
      @ctx = ctx
      # Values cast from +row+, by the same index. Only values in the row
      # are cast, so this is never longer than the row. Slots with a built
      # attribute are UNCAST here, so reads check this first.
      @casted_values = Array.new(row.size, UNCAST)
      @materialized = false
      @indexes = indexes
    end

    #: (ActiveModel::LazyIndexedAttributeSet) -> void
    def initialize_copy(other)
      super
      @casted_values = @casted_values.dup
    end

    #: (String) -> ActiveModel::Attribute
    def [](name)
      if index = index_for_name(name)
        attribute_at(name, index)
      else
        Attribute.null(name)
      end
    end

    #: (String, ActiveModel::Attribute) -> ActiveModel::Attribute
    def []=(name, attribute)
      store(indexes.fetch(name), attribute)
    end

    #: (String) -> bool
    def key?(name)
      index = index_for_name(name)
      return false unless index

      IndexedRow.key_at?(@row, index) ||
        ((@ctx.type_key_at?(index) || !lookup(index).nil?) && attribute_at(name, index).initialized?)
    end

    #: () -> Array[String]
    def keys
      keys = row_keys | @ctx.type_keys | cached_names
      keys.keep_if { |name| self[name].initialized? }
    end

    #: (String) ?{ (String) -> untyped } -> untyped
    def fetch_value(name, &block)
      index = index_for_name(name)
      return unless index

      value_at(index, name, &block)
    end

    #: (String) -> untyped
    def fetch_value!(name)
      index = index_for_name(name)
      return unless index

      value_at!(index, name)
    end

    # Rows are laid out by slot, so the slots that generated reader
    # methods pass are indexes into this set.
    #: (Integer) ?{ (String) -> untyped } -> untyped
    def fetch_value_at(index, &block)
      # Same as #value_at, inlined since generated readers call this.
      value = @casted_values.fetch(index, UNCAST)
      return value unless UNCAST.equal?(value)

      if (attrs = @attributes) && (attr = attrs[index])
        attr.value(&block)
      else
        cast_value(@ctx.name_at(index), index) { |attribute| attribute.value(&block) }
      end
    end

    #: (Integer) -> untyped
    def fetch_value_at!(index)
      value = @casted_values.fetch(index, UNCAST)
      return value unless UNCAST.equal?(value)

      if (attrs = @attributes) && (attr = attrs[index])
        attr.value!
      else
        cast_value(@ctx.name_at(index), index, &:value!)
      end
    end

    #: (String, untyped) -> ActiveModel::Attribute
    def write_from_database(name, value)
      write(name) { |attribute| attribute.with_value_from_database(value) }
    end

    #: (String, untyped) -> untyped
    def write_from_user(name, value)
      raise FrozenError, "can't modify frozen attributes" if frozen?
      index = index_for_name(name)
      attribute = write(name) { |attr| attr.with_value_from_user(value) }
      # Cast now so reads of the attribute stay on the fast path. Both hold
      # the same object, so changes made in place are still detected.
      @casted_values[index] = attribute.value if index < @casted_values.size
      value
    end

    #: (String, untyped) -> ActiveModel::Attribute
    def write_cast_value(name, value)
      write(name) { |attribute| attribute.with_cast_value(value) }
    end

    #: () -> ActiveModel::LazyIndexedAttributeSet
    def deep_dup
      map(&:deep_dup)
    end

    #: () { (ActiveModel::Attribute) -> ActiveModel::Attribute } -> ActiveModel::LazyIndexedAttributeSet
    def map(&block)
      materialize
      dup.transform_attributes!(&block)
    end

    protected
      # An IndexedRow of every attribute, for the methods that work on all
      # of them. Built on each call, so writes must go through #store.
      #: () -> ActiveModel::IndexedRow::Mutable
      def attributes
        materialize

        row = IndexedRow.unset_row(indexes.size)
        @attributes&.each_with_index { |attr, i| row[i] = attr if attr }
        IndexedRow::Mutable.new(indexes, row)
      end

      # Replaces each cached attribute with the block's result. Only for
      # fresh copies, since it modifies +@attributes+ in place. The new
      # attributes may hold new values, so their slots are uncast.
      #: () { (ActiveModel::Attribute) -> ActiveModel::Attribute } -> self
      def transform_attributes!
        return self unless @attributes

        size = @casted_values.size
        @attributes.each_with_index do |attr, i|
          next unless attr

          @attributes[i] = yield(attr)
          @casted_values[i] = UNCAST if i < size
        end
        self
      end

    private
      #: () -> void
      def materialize
        unless @materialized
          row_keys.each { |key| self[key] }
          @ctx.type_keys.each { |key| self[key] }
          @materialized = true
        end
      end

      # +indexes+ has every name the set can hold, so a name without an
      # index isn't an attribute.
      #: (String) -> Integer?
      def index_for_name(name)
        indexes[name]
      end

      #: (Integer) -> ActiveModel::Attribute?
      def lookup(index)
        @attributes&.[](index)
      end

      # The attribute now holds the value, so the cast value is dropped.
      #: (Integer, ActiveModel::Attribute) -> ActiveModel::Attribute
      def store(index, attribute)
        (@attributes ||= Array.new(indexes.size))[index] = attribute
        @casted_values[index] = UNCAST if index < @casted_values.size
        attribute
      end

      # These are on the path of every attribute read, so they check the
      # caches directly and only call out to cast a value the first time.
      #: (Integer, String) ?{ (String) -> untyped } -> untyped
      def value_at(index, name, &block)
        value = @casted_values.fetch(index, UNCAST)
        return value unless UNCAST.equal?(value)

        if (attrs = @attributes) && (attr = attrs[index])
          attr.value(&block)
        else
          cast_value(name, index) { |attribute| attribute.value(&block) }
        end
      end

      #: (Integer, String) -> untyped
      def value_at!(index, name)
        value = @casted_values.fetch(index, UNCAST)
        return value unless UNCAST.equal?(value)

        if (attrs = @attributes) && (attr = attrs[index])
          attr.value!
        else
          cast_value(name, index, &:value!)
        end
      end

      #: (String, Integer) -> ActiveModel::Attribute
      def attribute_at(name, index)
        lookup(index) || default_attribute(name, index)
      end

      # Stores the block's result for the attribute +name+. Unknown names
      # get Attribute::Null, which raises before anything is stored.
      #: (String) { (ActiveModel::Attribute) -> ActiveModel::Attribute } -> ActiveModel::Attribute
      def write(name)
        index = index_for_name(name)
        attribute = index ? attribute_at(name, index) : Attribute.null(name)
        store(index, yield(attribute))
      end

      # The value at +index+ for an attribute that hasn't been built or cast
      # yet: cast from the row (and kept in +@casted_values+), or the block's
      # result for the default attribute when the row doesn't have it.
      #: (String, Integer) { (ActiveModel::Attribute) -> untyped } -> untyped
      def cast_value(name, index)
        if IndexedRow.key_at?(@row, index)
          @casted_values[index] = type_for(index).deserialize(@row[index])
        else
          yield default_attribute(name, index, false, nil)
        end
      end

      #: (Integer) -> ActiveModel::Type::Value
      def type_for(index)
        @ctx.type_at(index, @indexes)
      end

      # Every name the set can hold.
      #: () -> Array[String]
      def row_keys
        indexes.keys
      end

      #: () -> Array[String]
      def cached_names
        names = []
        indexes.each_key { |name| names << name if lookup(index_for_name(name)) }
        names
      end

      #: () -> void
      def freeze_attributes
        materialize
        @attributes ||= Array.new(indexes.size)
        @attributes.freeze
      end

      #: (String, Integer, ?bool, ?untyped) -> ActiveModel::Attribute
      def default_attribute(
        name,
        index,
        value_present = IndexedRow.key_at?(@row, index),
        value = (@row[index] if value_present)
      )
        if value_present
          casted = @casted_values.fetch(index, UNCAST)
          casted = nil if UNCAST.equal?(casted)
          store(index, Attribute.from_database(name, value, type_for(index), casted))
        elsif @ctx.type_key_at?(index)
          if attr = @ctx.default_at(index)
            store(index, attr.dup)
          else
            store(index, Attribute.uninitialized(name, type_for(index)))
          end
        else
          Attribute.null(name)
        end
      end
  end

  # Records marshaled in the Rails 6.1 format have their instance variables
  # dumped directly, so their attribute sets load as this class (the name
  # of the lazy attribute set at the time), with their attributes in Hashes
  # by name. The first use builds every attribute and then works by name,
  # like an AttributeSet. Its layout isn't the model's, so it can't be read
  # by slot: the record lays it out like the model's first (see
  # ActiveRecord::AttributeMethods::Read#_read_attribute_at!).
  class LazyAttributeSet < AttributeSet # :nodoc:
    # Raised when reading by slot, which needs the model's layout.
    class NotLaidOut < StandardError # :nodoc:
    end

    #: (Integer) -> bot
    def fetch_value_at(index)
      raise NotLaidOut
    end

    #: (Integer) -> bot
    def fetch_value_at!(index)
      raise NotLaidOut
    end

    protected
      #: () -> ActiveModel::IndexedRow
      def attributes
        build_attributes if @attributes.is_a?(Hash)
        @attributes
      end

    private
      #: (String) -> ActiveModel::Attribute?
      def lookup(name)
        attributes[name]
      end

      #: (String, ActiveModel::Attribute) -> ActiveModel::Attribute
      def store(name, attribute)
        attributes[name] = attribute
      end

      # +@values+ and +@casted_values+ are Hashes, or IndexedRows in dumps
      # from later versions, so they're only read through methods both have.
      #: () -> ActiveModel::IndexedRow::Mutable
      def build_attributes
        built = @attributes
        names = @values.keys | @types.keys | built.keys
        attributes = names.index_with { |name| built[name] || build_attribute(name) }
        @attributes = IndexedRow::Mutable[attributes]
      end

      #: (String) -> ActiveModel::Attribute
      def build_attribute(name)
        type = @additional_types.fetch(name) { @types[name] } || Type.default_value

        if @values.key?(name)
          Attribute.from_database(name, @values[name], type, @casted_values.fetch(name) { nil })
        else
          default_keys = @default_keys if defined?(@default_keys)
          if (default_keys.nil? || default_keys.include?(name)) && (attr = @default_attributes.fetch(name) { nil })
            attr.dup
          else
            Attribute.uninitialized(name, type)
          end
        end
      end
  end

  # This is an adapter specifically for people using `becomes`.
  class ReindexedAttributeSet # :nodoc:
    #: (ActiveModel::AttributeSet | ActiveModel::ReindexedAttributeSet, ActiveModel::AttributeSet | ActiveModel::ReindexedAttributeSet) -> void
    def initialize(shared, own)
      @shared = shared
      @own = own
      @to_shared = to_shared_indexes
    end

    #: () -> (Hash[String, Integer] | ActiveModel::IndexedRow::ExtendedIndexes)
    def indexes
      @own.indexes
    end

    #: (String) -> ActiveModel::Attribute
    def [](name)
      set_for(name)[name]
    end

    #: (String, ActiveModel::Attribute) -> ActiveModel::Attribute
    def []=(name, attribute)
      set_for(name)[name] = attribute
    end

    #: (String) -> bool
    def key?(name)
      set_for(name).key?(name)
    end
    alias :include? :key?

    #: () -> Array[String]
    def keys
      @shared.keys | own_only(@own.keys)
    end

    #: (String) ?{ (String) -> untyped } -> untyped
    def fetch_value(name, &block)
      set_for(name).fetch_value(name, &block)
    end

    #: (String) -> untyped
    def fetch_value!(name)
      set_for(name).fetch_value!(name)
    end

    #: (Integer) ?{ (String) -> untyped } -> untyped
    def fetch_value_at(index, &block)
      if shared_index = @to_shared[index]
        @shared.fetch_value_at(shared_index, &block)
      else
        @own.fetch_value_at(index, &block)
      end
    end

    #: (Integer) -> untyped
    def fetch_value_at!(index)
      if shared_index = @to_shared[index]
        @shared.fetch_value_at!(shared_index)
      else
        @own.fetch_value_at!(index)
      end
    end

    #: (Integer) -> String?
    def name_at(index)
      @own.name_at(index)
    end

    #: (String, untyped) -> ActiveModel::Attribute
    def write_from_database(name, value)
      set_for(name).write_from_database(name, value)
    end

    #: (String, untyped) -> untyped
    def write_from_user(name, value)
      raise FrozenError, "can't modify frozen attributes" if frozen?
      set_for(name).write_from_user(name, value)
    end

    #: (String, untyped) -> ActiveModel::Attribute
    def write_cast_value(name, value)
      set_for(name).write_cast_value(name, value)
    end

    #: (String) -> ActiveModel::Attribute?
    def reset(name)
      set_for(name).reset(name)
    end

    #: () -> Hash[String, untyped]
    def to_hash
      keys.index_with { |name| self[name].value }
    end
    alias :to_h :to_hash

    #: () -> Hash[String, ActiveModel::Type::Value]
    def cast_types
      @shared.cast_types.merge(own_only(@own.cast_types))
    end

    #: () -> Hash[String, untyped]
    def values_before_type_cast
      @shared.values_before_type_cast.merge(own_only(@own.values_before_type_cast))
    end

    #: () -> Hash[String, untyped]
    def values_for_database
      @shared.values_for_database.merge(own_only(@own.values_for_database))
    end

    #: () -> Array[String]
    def accessed
      @shared.accessed | own_only(@own.accessed)
    end

    #: () { (ActiveModel::Attribute) -> void } -> self
    #: () -> Enumerator[ActiveModel::Attribute, self]
    def each_value(&block)
      return enum_for(:each_value) unless block

      @shared.each_value(&block)
      @own.each_value { |attribute| yield attribute unless shared?(attribute.name) }
      self
    end

    #: () -> Array[ActiveModel::Attribute]
    def values
      each_value.to_a
    end

    #: () { (ActiveModel::Attribute) -> ActiveModel::Attribute } -> ActiveModel::ReindexedAttributeSet
    def map(&block)
      self.class.new(@shared.map(&block), @own.map(&block))
    end

    #: () -> ActiveModel::ReindexedAttributeSet
    def deep_dup
      self.class.new(@shared.deep_dup, @own.deep_dup)
    end

    #: (ActiveModel::ReindexedAttributeSet) -> void
    def initialize_dup(_)
      @shared = @shared.dup
      @own = @own.dup
      super
    end

    #: (ActiveModel::ReindexedAttributeSet) -> void
    def initialize_clone(_)
      @shared = @shared.clone
      @own = @own.clone
      super
    end

    #: () -> self
    def freeze
      @shared.freeze
      @own.freeze
      super
    end

    #: (untyped) -> bool
    def ==(other)
      other.class == self.class && shared == other.shared && own == other.own
    end

    #: () -> bool
    def read_only?
      false
    end

    protected
      attr_reader :shared, :own

    private
      # The index in +shared+ for each index in +own+, or +nil+ where
      # +shared+ doesn't have the attribute.
      #: () -> Array[Integer?]
      def to_shared_indexes
        shared_indexes = @shared.indexes
        own_indexes = @own.indexes
        map = []
        own_indexes.each_key do |name|
          if entry = shared_indexes[name]
            map[own_indexes[name]] = entry
          end
        end
        map
      end

      #: (String) -> bool
      def shared?(name)
        @shared.indexes.key?(name)
      end

      #: (String) -> (ActiveModel::AttributeSet | ActiveModel::ReindexedAttributeSet)
      def set_for(name)
        shared?(name) ? @shared : @own
      end

      #: (Array[String] | Hash[String, untyped]) -> (Array[String] | Hash[String, untyped])
      def own_only(names)
        names.reject { |name, _| shared?(name) }
      end
  end
end
