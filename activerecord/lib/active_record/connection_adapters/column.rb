module ActiveRecord
  # :stopdoc:
  module ConnectionAdapters
    # An abstract definition of a column in a table.
    class Column
      attr_reader :name, :default, :sql_type_metadata, :null, :table_name, :default_function, :collation, :comment

      delegate :precision, :scale, :limit, :type, :sql_type, to: :sql_type_metadata, allow_nil: true

      # Instantiates a new column in the table.
      #
      # +name+ is the column's name, such as <tt>supplier_id</tt> in <tt>supplier_id int</tt>.
      # +default+ is the type-casted default value, such as +new+ in <tt>sales_stage varchar(20) default 'new'</tt>.
      # +sql_type_metadata+ is various information about the type of the column
      # +null+ determines if this column allows +NULL+ values.
      def initialize(name, default, sql_type_metadata = nil, null = true, table_name = nil, default_function = nil, collation = nil, comment: nil)
        @name = name.freeze
        @table_name = table_name
        @sql_type_metadata = sql_type_metadata
        @null = null
        @default = default
        @default_function = default_function
        @collation = collation
        @comment = comment
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
        @table_name = coder["table_name"]
        @sql_type_metadata = coder["sql_type_metadata"]
        @null = coder["null"]
        @default = coder["default"]
        @default_function = coder["default_function"]
        @collation = coder["collation"]
        @comment = coder["comment"]
      end

      def encode_with(coder)
        coder["name"] = @name
        coder["table_name"] = @table_name
        coder["sql_type_metadata"] = @sql_type_metadata
        coder["null"] = @null
        coder["default"] = @default
        coder["default_function"] = @default_function
        coder["collation"] = @collation
        coder["comment"] = @comment
      end

      def ==(other)
        other.is_a?(Column) &&
          attributes_for_hash == other.attributes_for_hash
      end
      alias :eql? :==

      def hash
        attributes_for_hash.hash
      end

      protected

        def attributes_for_hash
          [self.class, name, default, sql_type_metadata, null, table_name, default_function, collation]
        end
    end

    class NullColumn < Column
      def initialize(name)
        super(name, nil)
      end
    end
  end
  # :startdoc:
end
