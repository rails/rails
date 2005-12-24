require 'parsedate'

module ActiveRecord
  module ConnectionAdapters #:nodoc:
    # An abstract definition of a column in a table.
    class Column
      attr_reader :name, :default, :type, :limit, :null, :sql_type
      attr_accessor :primary

      # Instantiates a new column in the table.
      #
      # +name+ is the column's name, as in <tt><b>supplier_id</b> int(11)</tt>.
      # +default+ is the type-casted default value, such as <tt>sales_stage varchar(20) default <b>'new'</b></tt>.
      # +sql_type+ is only used to extract the column's length, if necessary.  For example, <tt>company_name varchar(<b>60</b>)</tt>.
      # +null+ determines if this column allows +NULL+ values.
      def initialize(name, default, sql_type = nil, null = true)
        @name, @type, @null = name, simplified_type(sql_type), null
        @sql_type = sql_type
        # have to do this one separately because type_cast depends on #type
        @default = type_cast(default)
        @limit   = extract_limit(sql_type) unless sql_type.nil?
        @primary = nil
        @text    = [:string, :text].include? @type
        @number  = [:float, :integer].include? @type
      end

      def text?
        @text
      end

      def number?
        @number
      end

      # Returns the Ruby class that corresponds to the abstract data type.
      def klass
        case type
          when :integer       then Fixnum
          when :float         then Float
          when :datetime      then Time
          when :date          then Date
          when :timestamp     then Time
          when :time          then Time
          when :text, :string then String
          when :binary        then String
          when :boolean       then Object
        end
      end

      # Casts value (which is a String) to an appropriate instance.
      def type_cast(value)
        return nil if value.nil?
        case type
          when :string    then value
          when :text      then value
          when :integer   then value.to_i rescue value ? 1 : 0
          when :float     then value.to_f
          when :datetime  then self.class.string_to_time(value)
          when :timestamp then self.class.string_to_time(value)
          when :time      then self.class.string_to_dummy_time(value)
          when :date      then self.class.string_to_date(value)
          when :binary    then self.class.binary_to_string(value)
          when :boolean   then self.class.value_to_boolean(value)
          else value
        end
      end

      def type_cast_code(var_name)
        case type
          when :string    then nil
          when :text      then nil
          when :integer   then "(#{var_name}.to_i rescue #{var_name} ? 1 : 0)"
          when :float     then "#{var_name}.to_f"
          when :datetime  then "#{self.class.name}.string_to_time(#{var_name})"
          when :timestamp then "#{self.class.name}.string_to_time(#{var_name})"
          when :time      then "#{self.class.name}.string_to_dummy_time(#{var_name})"
          when :date      then "#{self.class.name}.string_to_date(#{var_name})"
          when :binary    then "#{self.class.name}.binary_to_string(#{var_name})"
          when :boolean   then "#{self.class.name}.value_to_boolean(#{var_name})"
          else nil
        end
      end

      # Returns the human name of the column name.
      #
      # ===== Examples
      #  Column.new('sales_stage', ...).human_name #=> 'Sales stage'
      def human_name
        Base.human_attribute_name(@name)
      end

      # Used to convert from Strings to BLOBs
      def self.string_to_binary(value)
        value
      end

      # Used to convert from BLOBs to Strings
      def self.binary_to_string(value)
        value
      end

      def self.string_to_date(string)
        return string unless string.is_a?(String)
        date_array = ParseDate.parsedate(string)
        # treat 0000-00-00 as nil
        Date.new(date_array[0], date_array[1], date_array[2]) rescue nil
      end

      def self.string_to_time(string)
        return string unless string.is_a?(String)
        time_array = ParseDate.parsedate(string)[0..5]
        # treat 0000-00-00 00:00:00 as nil
        Time.send(Base.default_timezone, *time_array) rescue nil
      end

      def self.string_to_dummy_time(string)
        return string unless string.is_a?(String)
        time_array = ParseDate.parsedate(string)
        # pad the resulting array with dummy date information
        time_array[0] = 2000; time_array[1] = 1; time_array[2] = 1;
        Time.send(Base.default_timezone, *time_array) rescue nil
      end

      # convert something to a boolean
      def self.value_to_boolean(value)
        return value if value==true || value==false
        case value.to_s.downcase
        when "true", "t", "1" then true
        else false
        end
      end

    private
        def extract_limit(sql_type)
          $1.to_i if sql_type =~ /\((.*)\)/
        end

        def simplified_type(field_type)
          case field_type
            when /int/i
              :integer
            when /float|double|decimal|numeric/i
              :float
            when /datetime/i
              :datetime
            when /timestamp/i
              :timestamp
            when /time/i
              :time
            when /date/i
              :date
            when /clob/i, /text/i
              :text
            when /blob/i, /binary/i
              :binary
            when /char/i, /string/i
              :string
            when /boolean/i
              :boolean
          end
        end
    end

    class IndexDefinition < Struct.new(:table, :name, :unique, :columns) #:nodoc:
    end

    class ColumnDefinition < Struct.new(:base, :name, :type, :limit, :default, :null) #:nodoc:
      def to_sql
        column_sql = "#{base.quote_column_name(name)} #{type_to_sql(type.to_sym, limit)}"
        add_column_options!(column_sql, :null => null, :default => default)
        column_sql
      end
      alias to_s :to_sql

      private
        def type_to_sql(name, limit)
          base.type_to_sql(name, limit) rescue name
        end   

        def add_column_options!(sql, options)
          base.add_column_options!(sql, options.merge(:column => self))
        end
    end

    # Represents a SQL table in an abstract way.
    # Columns are stored as ColumnDefinition in the #columns attribute.
    class TableDefinition
      attr_accessor :columns

      def initialize(base)
        @columns = []
        @base = base
      end

      # Appends a primary key definition to the table definition.
      # Can be called multiple times, but this is probably not a good idea.
      def primary_key(name)
        column(name, native[:primary_key])
      end

      # Returns a ColumnDefinition for the column with name +name+.
      def [](name)
        @columns.find {|column| column.name.to_s == name.to_s}
      end

      # Instantiates a new column for the table.
      # The +type+ parameter must be one of the following values:
      # <tt>:primary_key</tt>, <tt>:string</tt>, <tt>:text</tt>,
      # <tt>:integer</tt>, <tt>:float</tt>, <tt>:datetime</tt>,
      # <tt>:timestamp</tt>, <tt>:time</tt>, <tt>:date</tt>,
      # <tt>:binary</tt>, <tt>:boolean</tt>.
      #
      # Available options are (none of these exists by default):
      # * <tt>:limit</tt>:
      #   Requests a maximum column length (<tt>:string</tt>, <tt>:text</tt>,
      #   <tt>:binary</tt> or <tt>:integer</tt> columns only)
      # * <tt>:default</tt>:
      #   The column's default value.  You cannot explicitely set the default
      #   value to +NULL+.  Simply leave off this option if you want a +NULL+
      #   default value.
      # * <tt>:null</tt>:
      #   Allows or disallows +NULL+ values in the column.  This option could
      #   have been named <tt>:null_allowed</tt>.
      #
      # This method returns <tt>self</tt>.
      #
      # ===== Examples
      #  # Assuming def is an instance of TableDefinition
      #  def.column(:granted, :boolean)
      #    #=> granted BOOLEAN
      #
      #  def.column(:picture, :binary, :limit => 2.megabytes)
      #    #=> picture BLOB(2097152)
      #
      #  def.column(:sales_stage, :string, :limit => 20, :default => 'new', :null => false)
      #    #=> sales_stage VARCHAR(20) DEFAULT 'new' NOT NULL
      def column(name, type, options = {})
        column = self[name] || ColumnDefinition.new(@base, name, type)
        column.limit = options[:limit] || native[type.to_sym][:limit] if options[:limit] or native[type.to_sym]
        column.default = options[:default]
        column.null = options[:null]
        @columns << column unless @columns.include? column
        self
      end

      # Returns a String whose contents are the column definitions
      # concatenated together.  This string can then be pre and appended to
      # to generate the final SQL to create the table.
      def to_sql
        @columns * ', '
      end

      private
        def native
          @base.native_database_types
        end
    end
  end
end
