require 'set'

module ActiveRecord
  # :stopdoc:
  module ConnectionAdapters
    # An abstract definition of a column in a table.
    class Column
      attr_reader :name, :null, :sql_type_metadata, :default, :default_function, :collation

      delegate :precision, :scale, :limit, :type, :sql_type, to: :sql_type_metadata, allow_nil: true

      # Instantiates a new column in the table.
      #
      # +name+ is the column's name, such as <tt>supplier_id</tt> in <tt>supplier_id int</tt>.
      # +default+ is the type-casted default value, such as +new+ in <tt>sales_stage varchar(20) default 'new'</tt>.
      # +sql_type_metadata+ is various information about the type of the column
      # +null+ determines if this column allows +NULL+ values.
      def initialize(name, default, sql_type_metadata = nil, null = true, default_function = nil, collation = nil)
        @name = name.freeze
        @sql_type_metadata = sql_type_metadata
        @null = null
        @default = default
        @default_function = default_function
        @collation = collation
        @table_name = nil
      end

      def has_default?
        !default.nil? || default_function
      end

      def bigint?
        /\Abigint\b/ === sql_type
      end

      # Returns the human name of the column name.
      #
      # ===== Examples
      #  Column.new('sales_stage', ...).human_name # => 'Sales stage'
      def human_name
        Base.human_attribute_name(@name)
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
        [self.class, name, default, sql_type_metadata, null, default_function, collation]
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
