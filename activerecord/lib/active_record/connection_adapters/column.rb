require 'set'

module ActiveRecord
  # :stopdoc:
  module ConnectionAdapters
    # An abstract definition of a column in a table.
    class Column
      TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE', 'on', 'ON'].to_set
      FALSE_VALUES = [false, 0, '0', 'f', 'F', 'false', 'FALSE', 'off', 'OFF'].to_set

      module Format
        ISO_DATE = /\A(\d{4})-(\d\d)-(\d\d)\z/
        ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?\z/
      end

      attr_reader :name, :cast_type, :null, :sql_type, :default, :default_function

      delegate :type, :precision, :scale, :limit, :klass, :accessor,
        :text?, :number?, :binary?, :changed?,
        :type_cast_from_user, :type_cast_from_database, :type_cast_for_database,
        :type_cast_for_schema,
        to: :cast_type

      # Instantiates a new column in the table.
      #
      # +name+ is the column's name, such as <tt>supplier_id</tt> in <tt>supplier_id int(11)</tt>.
      # +default+ is the type-casted default value, such as +new+ in <tt>sales_stage varchar(20) default 'new'</tt>.
      # +cast_type+ is the object used for type casting and type information.
      # +sql_type+ is used to extract the column's length, if necessary. For example +60+ in
      # <tt>company_name varchar(60)</tt>.
      # It will be mapped to one of the standard Rails SQL types in the <tt>type</tt> attribute.
      # +null+ determines if this column allows +NULL+ values.
      def initialize(name, default, cast_type, sql_type = nil, null = true)
        @name             = name.freeze
        @cast_type        = cast_type
        @sql_type         = sql_type
        @null             = null
        @default          = default
        @default_function = nil
      end

      def has_default?
        !default.nil?
      end

      # Returns the human name of the column name.
      #
      # ===== Examples
      #  Column.new('sales_stage', ...).human_name # => 'Sales stage'
      def human_name
        Base.human_attribute_name(@name)
      end

      def with_type(type)
        dup.tap do |clone|
          clone.instance_variable_set('@cast_type', type)
        end
      end

      def ==(other)
        other.name == name &&
          other.default == default &&
          other.cast_type == cast_type &&
          other.sql_type == sql_type &&
          other.null == null &&
          other.default_function == default_function
      end
      alias :eql? :==

      def hash
        attributes_for_hash.hash
      end

      private

      def attributes_for_hash
        [self.class, name, default, cast_type, sql_type, null, default_function]
      end
    end
  end
  # :startdoc:
end
