# frozen_string_literal: true

module ActiveRecord
  # :stopdoc:
  module ConnectionAdapters
    # An abstract definition of a column in a table.
    class Column
      include Deduplicable

      attr_reader :name, :cast_type, :default, :sql_type_metadata, :primary, :primary_idx, :null, :default_function, :collation, :comment

      delegate :precision, :scale, :limit, :type, :sql_type, to: :sql_type_metadata, allow_nil: true

      # Instantiates a new column in the table.
      #
      # +name+ is the column's name, such as <tt>supplier_id</tt> in <tt>supplier_id bigint</tt>.
      # +default+ is the type-casted default value, such as +new+ in <tt>sales_stage varchar(20) default 'new'</tt>.
      # +sql_type_metadata+ is various information about the type of the column
      # +null+ determines if this column allows +NULL+ values.
      def initialize(name, cast_type, default, sql_type_metadata = nil, primary = false, primary_idx = nil, null = true, default_function = nil, collation: nil, comment: nil, **)
        @name = name.freeze
        @cast_type = cast_type
        @sql_type_metadata = sql_type_metadata
        @primary = primary
        @primary_idx = primary_idx
        @null = null
        @default = default
        @default_function = default_function
        @collation = collation
        @comment = comment
      end

      def primary?
        @primary
      end

      def has_default?
        !default.nil? || default_function
      end

      def bigint?
        /\Abigint\b/.match?(sql_type)
      end

      # Returns the human name of the column name.
      #
      # ===== Examples
      #  Column.new('sales_stage', ...).human_name # => 'Sales stage'
      def human_name
        Base.human_attribute_name(@name)
      end

      def init_with(coder)
        @name = coder["name"]
        @cast_type = coder["cast_type"]
        @sql_type_metadata = coder["sql_type_metadata"]
        @primary = coder["primary"]
        @primary_idx = coder["primary_idx"]
        @null = coder["null"]
        @default = coder["default"]
        @default_function = coder["default_function"]
        @collation = coder["collation"]
        @comment = coder["comment"]
      end

      def encode_with(coder)
        coder["name"] = @name
        coder["cast_type"] = @cast_type
        coder["sql_type_metadata"] = @sql_type_metadata
        coder["primary"] = @primary
        coder["primary_idx"] = @primary_idx
        coder["null"] = @null
        coder["default"] = @default
        coder["default_function"] = @default_function
        coder["collation"] = @collation
        coder["comment"] = @comment
      end

      # whether the column is auto-populated by the database using a sequence
      def auto_incremented_by_db?
        false
      end

      def auto_populated?
        auto_incremented_by_db? || default_function
      end

      def ==(other)
        other.is_a?(Column) &&
          name == other.name &&
          cast_type == other.cast_type &&
          sql_type_metadata == other.sql_type_metadata &&
          primary == other.primary &&
          primary_idx == other.primary_idx &&
          null == other.null &&
          default == other.default &&
          default_function == other.default_function &&
          collation == other.collation &&
          comment == other.comment
      end
      alias :eql? :==

      def hash
        Column.hash ^
          name.hash ^
          name.encoding.hash ^
          cast_type.hash ^
          sql_type_metadata.hash ^
          primary.hash ^
          primary_idx.hash ^
          null.hash ^
          default.hash ^
          default_function.hash ^
          collation.hash ^
          comment.hash
      end

      def virtual?
        false
      end

      private
        def deduplicated
          @name = -name
          @sql_type_metadata = sql_type_metadata.deduplicate if sql_type_metadata
          @default = -default if default
          @default_function = -default_function if default_function
          @collation = -collation if collation
          @comment = -comment if comment
          super
        end
    end

    class NullColumn < Column
      def initialize(name, **)
        super(name, nil, nil)
      end
    end
  end
  # :startdoc:
end
