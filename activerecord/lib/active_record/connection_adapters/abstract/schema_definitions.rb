require 'date'
require 'bigdecimal'
require 'bigdecimal/util'

module ActiveRecord
  module ConnectionAdapters #:nodoc:
    # An abstract definition of a column in a table.
    class Column
      module Format
        ISO_DATE = /\A(\d{4})-(\d\d)-(\d\d)\z/
        ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?\z/
      end

      attr_reader :name, :default, :type, :limit, :null, :sql_type, :precision, :scale
      attr_accessor :primary

      # Instantiates a new column in the table.
      #
      # +name+ is the column's name, as in <tt><b>supplier_id</b> int(11)</tt>.
      # +default+ is the type-casted default value, such as <tt>sales_stage varchar(20) default <b>'new'</b></tt>.
      # +sql_type+ is only used to extract the column's length, if necessary.  For example, <tt>company_name varchar(<b>60</b>)</tt>.
      # +null+ determines if this column allows +NULL+ values.
      def initialize(name, default, sql_type = nil, null = true)
        @name, @sql_type, @null = name, sql_type, null
        @limit, @precision, @scale  = extract_limit(sql_type), extract_precision(sql_type), extract_scale(sql_type) 
        @type = simplified_type(sql_type)
        @default = extract_default(default)

        @primary = nil
      end

      def text?
        [:string, :text].include? type
      end

      def number?
        [:float, :integer, :decimal].include? type
      end

      # Returns the Ruby class that corresponds to the abstract data type.
      def klass
        case type
          when :integer       then Fixnum
          when :float         then Float
          when :decimal       then BigDecimal
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
          when :decimal   then self.class.value_to_decimal(value)
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
          when :decimal   then "#{self.class.name}.value_to_decimal(#{var_name})"
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

      def extract_default(default)
        type_cast(default)
      end

      class << self
        # Used to convert from Strings to BLOBs
        def string_to_binary(value)
          value
        end

        # Used to convert from BLOBs to Strings
        def binary_to_string(value)
          value
        end

        def string_to_date(string)
          return string unless string.is_a?(String)
          return nil if string.empty?

          fast_string_to_date(string) || fallback_string_to_date(string)
        end

        def string_to_time(string)
          return string unless string.is_a?(String)
          return nil if string.empty?

          fast_string_to_time(string) || fallback_string_to_time(string)
        end

        def string_to_dummy_time(string)
          return string unless string.is_a?(String)
          return nil if string.empty?

          string_to_time "2000-01-01 #{string}"
        end

        # convert something to a boolean
        def value_to_boolean(value)
          if value == true || value == false
            value
          else
            %w(true t 1).include?(value.to_s.downcase)
          end
        end

        # convert something to a BigDecimal
        def value_to_decimal(value)
          if value.is_a?(BigDecimal)
            value
          elsif value.respond_to?(:to_d)
            value.to_d
          else
            value.to_s.to_d
          end
        end

        protected
          # '0.123456' -> 123456
          # '1.123456' -> 123456
          def microseconds(time)
            ((time[:sec_fraction].to_f % 1) * 1_000_000).to_i
          end

          def new_date(year, mon, mday)
            if year && year != 0
              Date.new(year, mon, mday) rescue nil
            end
          end

          def new_time(year, mon, mday, hour, min, sec, microsec)
            # Treat 0000-00-00 00:00:00 as nil.
            return nil if year.nil? || year == 0

            Time.send(Base.default_timezone, year, mon, mday, hour, min, sec, microsec)
          # Over/underflow to DateTime
          rescue ArgumentError, TypeError
            zone_offset = Base.default_timezone == :local ? DateTime.local_offset : 0
            DateTime.civil(year, mon, mday, hour, min, sec, zone_offset) rescue nil
          end

          def fast_string_to_date(string)
            if string =~ Format::ISO_DATE
              new_date $1.to_i, $2.to_i, $3.to_i
            end
          end

          # Doesn't handle time zones.
          def fast_string_to_time(string)
            if string =~ Format::ISO_DATETIME
              microsec = ($7.to_f * 1_000_000).to_i
              new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
            end
          end

          def fallback_string_to_date(string)
            new_date(*ParseDate.parsedate(string)[0..2])
          end

          def fallback_string_to_time(string)
            time_hash = Date._parse(string)
            time_hash[:sec_fraction] = microseconds(time_hash)

            new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction))
          end
      end

      private
        def extract_limit(sql_type)
          $1.to_i if sql_type =~ /\((.*)\)/
        end

        def extract_precision(sql_type)
          $2.to_i if sql_type =~ /^(numeric|decimal|number)\((\d+)(,\d+)?\)/i
        end

        def extract_scale(sql_type)
          case sql_type
            when /^(numeric|decimal|number)\((\d+)\)/i then 0
            when /^(numeric|decimal|number)\((\d+)(,(\d+))\)/i then $4.to_i
          end
        end

        def simplified_type(field_type)
          case field_type
            when /int/i
              :integer
            when /float|double/i
              :float
            when /decimal|numeric|number/i
              extract_scale(field_type) == 0 ? :integer : :decimal
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

    class ColumnDefinition < Struct.new(:base, :name, :type, :limit, :precision, :scale, :default, :null) #:nodoc:
      
      def sql_type
        base.type_to_sql(type.to_sym, limit, precision, scale) rescue type
      end
      
      def to_sql
        column_sql = "#{base.quote_column_name(name)} #{sql_type}"
        add_column_options!(column_sql, :null => null, :default => default) unless type.to_sym == :primary_key
        column_sql
      end
      alias to_s :to_sql

      private

        def add_column_options!(sql, options)
          base.add_column_options!(sql, options.merge(:column => self))
        end
    end

    # Represents a SQL table in an abstract way.
    # Columns are stored as a ColumnDefinition in the #columns attribute.
    class TableDefinition
      attr_accessor :columns

      def initialize(base)
        @columns = []
        @base = base
      end

      # Appends a primary key definition to the table definition.
      # Can be called multiple times, but this is probably not a good idea.
      def primary_key(name)
        column(name, :primary_key)
      end

      # Returns a ColumnDefinition for the column with name +name+.
      def [](name)
        @columns.find {|column| column.name.to_s == name.to_s}
      end

      # Instantiates a new column for the table.
      # The +type+ parameter is normally one of the migrations native types,
      # which is one of the following:
      # <tt>:primary_key</tt>, <tt>:string</tt>, <tt>:text</tt>,
      # <tt>:integer</tt>, <tt>:float</tt>, <tt>:decimal</tt>,
      # <tt>:datetime</tt>, <tt>:timestamp</tt>, <tt>:time</tt>,
      # <tt>:date</tt>, <tt>:binary</tt>, <tt>:boolean</tt>.
      #
      # You may use a type not in this list as long as it is supported by your
      # database (for example, "polygon" in MySQL), but this will not be database
      # agnostic and should usually be avoided.
      #
      # Available options are (none of these exists by default):
      # * <tt>:limit</tt> -
      #   Requests a maximum column length (<tt>:string</tt>, <tt>:text</tt>,
      #   <tt>:binary</tt> or <tt>:integer</tt> columns only)
      # * <tt>:default</tt> -
      #   The column's default value. Use nil for NULL.
      # * <tt>:null</tt> -
      #   Allows or disallows +NULL+ values in the column.  This option could
      #   have been named <tt>:null_allowed</tt>.
      # * <tt>:precision</tt> -
      #   Specifies the precision for a <tt>:decimal</tt> column. 
      # * <tt>:scale</tt> -
      #   Specifies the scale for a <tt>:decimal</tt> column. 
      #
      # Please be aware of different RDBMS implementations behavior with
      # <tt>:decimal</tt> columns:
      # * The SQL standard says the default scale should be 0, <tt>:scale</tt> <=
      #   <tt>:precision</tt>, and makes no comments about the requirements of
      #   <tt>:precision</tt>.
      # * MySQL: <tt>:precision</tt> [1..63], <tt>:scale</tt> [0..30]. 
      #   Default is (10,0).
      # * PostgreSQL: <tt>:precision</tt> [1..infinity], 
      #   <tt>:scale</tt> [0..infinity]. No default.
      # * SQLite2: Any <tt>:precision</tt> and <tt>:scale</tt> may be used. 
      #   Internal storage as strings. No default.
      # * SQLite3: No restrictions on <tt>:precision</tt> and <tt>:scale</tt>,
      #   but the maximum supported <tt>:precision</tt> is 16. No default.
      # * Oracle: <tt>:precision</tt> [1..38], <tt>:scale</tt> [-84..127]. 
      #   Default is (38,0).
      # * DB2: <tt>:precision</tt> [1..63], <tt>:scale</tt> [0..62]. 
      #   Default unknown.
      # * Firebird: <tt>:precision</tt> [1..18], <tt>:scale</tt> [0..18]. 
      #   Default (9,0). Internal types NUMERIC and DECIMAL have different
      #   storage rules, decimal being better.
      # * FrontBase?: <tt>:precision</tt> [1..38], <tt>:scale</tt> [0..38]. 
      #   Default (38,0). WARNING Max <tt>:precision</tt>/<tt>:scale</tt> for
      #   NUMERIC is 19, and DECIMAL is 38.
      # * SqlServer?: <tt>:precision</tt> [1..38], <tt>:scale</tt> [0..38]. 
      #   Default (38,0).
      # * Sybase: <tt>:precision</tt> [1..38], <tt>:scale</tt> [0..38]. 
      #   Default (38,0).
      # * OpenBase?: Documentation unclear. Claims storage in <tt>double</tt>.
      #
      # This method returns <tt>self</tt>.
      #
      # == Examples
      #  # Assuming td is an instance of TableDefinition
      #  td.column(:granted, :boolean)
      #    #=> granted BOOLEAN
      #
      #  td.column(:picture, :binary, :limit => 2.megabytes)
      #    #=> picture BLOB(2097152)
      #
      #  td.column(:sales_stage, :string, :limit => 20, :default => 'new', :null => false)
      #    #=> sales_stage VARCHAR(20) DEFAULT 'new' NOT NULL
      #
      #  def.column(:bill_gates_money, :decimal, :precision => 15, :scale => 2)
      #    #=> bill_gates_money DECIMAL(15,2)
      #
      #  def.column(:sensor_reading, :decimal, :precision => 30, :scale => 20)
      #    #=> sensor_reading DECIMAL(30,20)
      #
      #  # While <tt>:scale</tt> defaults to zero on most databases, it
      #  # probably wouldn't hurt to include it.
      #  def.column(:huge_integer, :decimal, :precision => 30)
      #    #=> huge_integer DECIMAL(30)
      #
      # == Short-hand examples
      #
      # Instead of calling column directly, you can also work with the short-hand definitions for the default types.
      # They use the type as the method name instead of as a parameter and allow for multiple columns to be defined
      # in a single statement.
      #
      # What can be written like this with the regular calls to column:
      #
      #   create_table "products", :force => true do |t|
      #     t.column "shop_id",    :integer
      #     t.column "creator_id", :integer
      #     t.column "name",       :string,   :default => "Untitled"
      #     t.column "value",      :string,   :default => "Untitled"
      #     t.column "created_at", :datetime
      #     t.column "updated_at", :datetime
      #   end
      #
      # Can also be written as follows using the short-hand:
      #
      #   create_table :products do |t|
      #     t.integer :shop_id, :creator_id
      #     t.string  :name, :value, :default => "Untitled"
      #     t.timestamps
      #   end
      #
      # There's a short-hand method for each of the type values declared at the top. And then there's 
      # TableDefinition#timestamps that'll add created_at and updated_at as datetimes.
      #
      # TableDefinition#references will add an appropriately-named _id column, plus a corresponding _type
      # column if the :polymorphic option is supplied. If :polymorphic is a hash of options, these will be
      # used when creating the _type column. So what can be written like this:
      #
      #   create_table :taggings do |t|
      #     t.integer :tag_id, :tagger_id, :taggable_id
      #     t.string  :tagger_type
      #     t.string  :taggable_type, :default => 'Photo'
      #   end
      #
      # Can also be written as follows using references:
      #
      #   create_table :taggings do |t|
      #     t.references :tag
      #     t.references :tagger, :polymorphic => true
      #     t.references :taggable, :polymorphic => { :default => 'Photo' }
      #   end
      def column(name, type, options = {})
        column = self[name] || ColumnDefinition.new(@base, name, type)
        if options[:limit]
          column.limit = options[:limit]
        elsif native[type.to_sym].is_a?(Hash)
          column.limit = native[type.to_sym][:limit]
        end
        column.precision = options[:precision]
        column.scale = options[:scale]
        column.default = options[:default]
        column.null = options[:null]
        @columns << column unless @columns.include? column
        self
      end

      %w( string text integer float decimal datetime timestamp time date binary boolean ).each do |column_type|
        class_eval <<-EOV
          def #{column_type}(*args)
            options = args.extract_options!
            column_names = args
            
            column_names.each { |name| column(name, '#{column_type}', options) }
          end
        EOV
      end
      
      # Appends <tt>:datetime</tt> columns <tt>:created_at</tt> and 
      # <tt>:updated_at</tt> to the table.
      def timestamps
        column(:created_at, :datetime)
        column(:updated_at, :datetime)
      end

      def references(*args)
        options = args.extract_options!
        polymorphic = options.delete(:polymorphic)
        args.each do |col|
          column("#{col}_id", :integer, options)
          column("#{col}_type", :string, polymorphic.is_a?(Hash) ? polymorphic : options) unless polymorphic.nil?
        end
      end
      alias :belongs_to :references

      # Returns a String whose contents are the column definitions
      # concatenated together.  This string can then be prepended and appended to
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
