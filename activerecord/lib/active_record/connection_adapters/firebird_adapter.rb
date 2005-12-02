# Author: Ken Kunz <kennethkunz@gmail.com>

require 'active_record/connection_adapters/abstract_adapter'

module FireRuby # :nodoc: all
  class Database
    def self.new_from_params(database, host, port, service)
      db_string = ""
      if host
        db_string << host
        db_string << "/#{service || port}" if service || port
        db_string << ":"
      end
      db_string << database
      new(db_string)
    end
  end
end

module ActiveRecord
  class << Base
    def firebird_connection(config) # :nodoc:
      require_library_or_gem 'fireruby'
      unless defined? FireRuby::SQLType
        raise AdapterNotFound,
          'The Firebird adapter requires FireRuby version 0.4.0 or greater; you appear ' <<
          'to be running an older version -- please update FireRuby (gem install fireruby).'
      end
      config = config.symbolize_keys
      unless config.has_key?(:database)
        raise ArgumentError, "No database specified. Missing argument: database."
      end
      options = config[:charset] ? { CHARACTER_SET => config[:charset] } : {}
      connection_params = [config[:username], config[:password], options]
      db = FireRuby::Database.new_from_params(*config.values_at(:database, :host, :port, :service))
      connection = db.connect(*connection_params)
      ConnectionAdapters::FirebirdAdapter.new(connection, logger, connection_params)
    end
  end

  module ConnectionAdapters
    class FirebirdColumn < Column # :nodoc:
      VARCHAR_MAX_LENGTH = 32_765
      BLOB_MAX_LENGTH    = 32_767

      def initialize(name, domain, type, sub_type, length, precision, scale, default_source, null_flag)
        @firebird_type = FireRuby::SQLType.to_base_type(type, sub_type).to_s
        super(name.downcase, nil, @firebird_type, !null_flag)
        @default = parse_default(default_source) if default_source
        @limit = type == 'BLOB' ? BLOB_MAX_LENGTH : length
        @domain, @sub_type, @precision, @scale = domain, sub_type, precision, scale
      end

      def type
        if @domain =~ /BOOLEAN/
          :boolean
        elsif @type == :binary and @sub_type == 1
          :text
        else
          @type
        end
      end

      # Submits a _CAST_ query to the database, casting the default value to the specified SQL type.
      # This enables Firebird to provide an actual value when context variables are used as column
      # defaults (such as CURRENT_TIMESTAMP).
      def default
        if @default
          sql = "SELECT CAST(#{@default} AS #{column_def}) FROM RDB$DATABASE"
          connection = ActiveRecord::Base.active_connections.values.detect { |conn| conn && conn.adapter_name == 'Firebird' }
          if connection
            type_cast connection.execute(sql).to_a.first['CAST']
          else
            raise ConnectionNotEstablished, "No Firebird connections established."
          end
        end
      end

      def type_cast(value)
        if type == :boolean
          value == true or value == ActiveRecord::ConnectionAdapters::FirebirdAdapter.boolean_domain[:true]
        else
          super
        end
      end

      private
        def parse_default(default_source)
          default_source =~ /^\s*DEFAULT\s+(.*)\s*$/i
          return $1 unless $1.upcase == "NULL"
        end

        def column_def
          case @firebird_type
            when 'BLOB'               then "VARCHAR(#{VARCHAR_MAX_LENGTH})"
            when 'CHAR', 'VARCHAR'    then "#{@firebird_type}(#{@limit})"
            when 'NUMERIC', 'DECIMAL' then "#{@firebird_type}(#{@precision},#{@scale.abs})"
            when 'DOUBLE'             then "DOUBLE PRECISION"
            else @firebird_type
          end
        end

        def simplified_type(field_type)
          if field_type == 'TIMESTAMP'
            :datetime
          else
            super
          end
        end
    end

    # The Firebird adapter relies on the FireRuby[http://rubyforge.org/projects/fireruby/]
    # extension, version 0.4.0 or later (available as a gem or from
    # RubyForge[http://rubyforge.org/projects/fireruby/]). FireRuby works with
    # Firebird 1.5.x on Linux, OS X and Win32 platforms.
    #
    # == Usage Notes
    #
    # === Sequence (Generator) Names
    # The Firebird adapter supports the same approach adopted for the Oracle
    # adapter. See ActiveRecord::Base#set_sequence_name for more details.
    #
    # Note that in general there is no need to create a <tt>BEFORE INSERT</tt>
    # trigger corresponding to a Firebird sequence generator when using
    # ActiveRecord. In other words, you don't have to try to make Firebird
    # simulate an <tt>AUTO_INCREMENT</tt> or +IDENTITY+ column. When saving a
    # new record, ActiveRecord pre-fetches the next sequence value for the table
    # and explicitly includes it in the +INSERT+ statement. (Pre-fetching the
    # next primary key value is the only reliable method for the Firebird
    # adapter to report back the +id+ after a successful insert.)
    #
    # === BOOLEAN Domain
    # Firebird 1.5 does not provide a native +BOOLEAN+ type. But you can easily
    # define a +BOOLEAN+ _domain_ for this purpose, e.g.:
    #
    #  CREATE DOMAIN D_BOOLEAN AS SMALLINT CHECK (VALUE IN (0, 1));
    #
    # When the Firebird adapter encounters a column that is based on a domain
    # that includes "BOOLEAN" in the domain name, it will attempt to treat
    # the column as a +BOOLEAN+.
    #
    # By default, the Firebird adapter will assume that the BOOLEAN domain is
    # defined as above.  This can be modified if needed.  For example, if you
    # have a legacy schema with the following +BOOLEAN+ domain defined:
    #
    #  CREATE DOMAIN BOOLEAN AS CHAR(1) CHECK (VALUE IN ('T', 'F'));
    #
    # ...you can add the following line to your <tt>environment.rb</tt> file:
    #
    #  ActiveRecord::ConnectionAdapters::FirebirdAdapter.boolean_domain = { :true => 'T', :false => 'F' }
    #
    # === BLOB Elements
    # The Firebird adapter currently provides only limited support for +BLOB+
    # columns. You cannot currently retrieve or insert a +BLOB+ as an IO stream.
    # When selecting a +BLOB+, the entire element is converted into a String.
    # When inserting or updating a +BLOB+, the entire value is included in-line
    # in the SQL statement, limiting you to values <= 32KB in size.
    #
    # === Column Name Case Semantics
    # Firebird and ActiveRecord have somewhat conflicting case semantics for
    # column names.
    #
    # [*Firebird*]
    #   The standard practice is to use unquoted column names, which can be
    #   thought of as case-insensitive. (In fact, Firebird converts them to
    #   uppercase.) Quoted column names (not typically used) are case-sensitive.
    # [*ActiveRecord*]
    #   Attribute accessors corresponding to column names are case-sensitive.
    #   The defaults for primary key and inheritance columns are lowercase, and
    #   in general, people use lowercase attribute names.
    #
    # In order to map between the differing semantics in a way that conforms
    # to common usage for both Firebird and ActiveRecord, uppercase column names
    # in Firebird are converted to lowercase attribute names in ActiveRecord,
    # and vice-versa. Mixed-case column names retain their case in both
    # directions. Lowercase (quoted) Firebird column names are not supported.
    # This is similar to the solutions adopted by other adapters.
    #
    # In general, the best approach is to use unqouted (case-insensitive) column
    # names in your Firebird DDL (or if you must quote, use uppercase column
    # names). These will correspond to lowercase attributes in ActiveRecord.
    #
    # For example, a Firebird table based on the following DDL:
    #
    #  CREATE TABLE products (
    #    id BIGINT NOT NULL PRIMARY KEY,
    #    "TYPE" VARCHAR(50),
    #    name VARCHAR(255) );
    #
    # ...will correspond to an ActiveRecord model class called +Product+ with
    # the following attributes: +id+, +type+, +name+.
    #
    # ==== Quoting <tt>"TYPE"</tt> and other Firebird reserved words:
    # In ActiveRecord, the default inheritance column name is +type+. The word
    # _type_ is a Firebird reserved word, so it must be quoted in any Firebird
    # SQL statements. Because of the case mapping described above, you should
    # always reference this column using quoted-uppercase syntax
    # (<tt>"TYPE"</tt>) within Firebird DDL or other SQL statements (as in the
    # example above). This holds true for any other Firebird reserved words used
    # as column names as well.
    #
    # === Migrations
    # The Firebird adapter does not currently support Migrations.  I hope to
    # add this feature in the near future.
    #
    # == Connection Options
    # The following options are supported by the Firebird adapter. None of the
    # options have default values.
    #
    # <tt>:database</tt>::
    #   <i>Required option.</i> Specifies one of: (i) a Firebird database alias;
    #   (ii) the full path of a database file; _or_ (iii) a full Firebird
    #   connection string. <i>Do not specify <tt>:host</tt>, <tt>:service</tt>
    #   or <tt>:port</tt> as separate options when using a full connection
    #   string.</i>
    # <tt>:host</tt>::
    #   Set to <tt>"remote.host.name"</tt> for remote database connections.
    #   May be omitted for local connections if a full database path is
    #   specified for <tt>:database</tt>. Some platforms require a value of
    #   <tt>"localhost"</tt> for local connections when using a Firebird
    #   database _alias_.
    # <tt>:service</tt>::
    #   Specifies a service name for the connection. Only used if <tt>:host</tt>
    #   is provided. Required when connecting to a non-standard service.
    # <tt>:port</tt>::
    #   Specifies the connection port. Only used if <tt>:host</tt> is provided
    #   and <tt>:service</tt> is not. Required when connecting to a non-standard
    #   port and <tt>:service</tt> is not defined.
    # <tt>:username</tt>::
    #   Specifies the database user. May be omitted or set to +nil+ (together
    #   with <tt>:password</tt>) to use the underlying operating system user
    #   credentials on supported platforms.
    # <tt>:password</tt>::
    #   Specifies the database password. Must be provided if <tt>:username</tt>
    #   is explicitly specified; should be omitted if OS user credentials are
    #   are being used.
    # <tt>:charset</tt>::
    #   Specifies the character set to be used by the connection. Refer to
    #   Firebird documentation for valid options.
    class FirebirdAdapter < AbstractAdapter
      @@boolean_domain = { :true => 1, :false => 0 }
      cattr_accessor :boolean_domain

      def initialize(connection, logger, connection_params=nil)
        super(connection, logger)
        @connection_params = connection_params
      end

      def adapter_name # :nodoc:
        'Firebird'
      end

      # Returns true for Firebird adapter (since Firebird requires primary key
      # values to be pre-fetched before insert). See also #next_sequence_value.
      def prefetch_primary_key?(table_name = nil)
        true
      end

      def default_sequence_name(table_name, primary_key) # :nodoc:
        "#{table_name}_seq"
      end


      # QUOTING ==================================================

      def quote(value, column = nil) # :nodoc:
        if [Time, DateTime].include?(value.class)
          "CAST('#{value.strftime("%Y-%m-%d %H:%M:%S")}' AS TIMESTAMP)"
        else
          super
        end
      end

      def quote_string(string) # :nodoc:
        string.gsub(/'/, "''")
      end

      def quote_column_name(column_name) # :nodoc:
        %Q("#{ar_to_fb_case(column_name)}")
      end

      def quoted_true # :nodoc:
        quote(boolean_domain[:true])
      end

      def quoted_false # :nodoc:
        quote(boolean_domain[:false])
      end


      # CONNECTION MANAGEMENT ====================================

      def active?
        not @connection.closed?
      end

      def reconnect!
        @connection.close
        @connection = @connection.database.connect(*@connection_params)
      end


      # DATABASE STATEMENTS ======================================

      def select_all(sql, name = nil) # :nodoc:
        select(sql, name)
      end

      def select_one(sql, name = nil) # :nodoc:
        result = select(sql, name)
        result.nil? ? nil : result.first
      end

      def execute(sql, name = nil, &block) # :nodoc:
        log(sql, name) do
          if @transaction
            @connection.execute(sql, @transaction, &block)
          else
            @connection.execute_immediate(sql, &block)
          end
        end
      end

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) # :nodoc:
        execute(sql, name)
        id_value
      end

      alias_method :update, :execute
      alias_method :delete, :execute

      def begin_db_transaction() # :nodoc:
        @transaction = @connection.start_transaction
      end

      def commit_db_transaction() # :nodoc:
        @transaction.commit
      ensure
        @transaction = nil
      end

      def rollback_db_transaction() # :nodoc:
        @transaction.rollback
      ensure
        @transaction = nil
      end

      def add_limit_offset!(sql, options) # :nodoc:
        if options[:limit]
          limit_string = "FIRST #{options[:limit]}"
          limit_string << " SKIP #{options[:offset]}" if options[:offset]
          sql.sub!(/\A(\s*SELECT\s)/i, '\&' + limit_string + ' ')
        end
      end

      # Returns the next sequence value from a sequence generator. Not generally
      # called directly; used by ActiveRecord to get the next primary key value
      # when inserting a new database record (see #prefetch_primary_key?).
      def next_sequence_value(sequence_name)
        FireRuby::Generator.new(sequence_name, @connection).next(1)
      end


      # SCHEMA STATEMENTS ========================================

      def columns(table_name, name = nil) # :nodoc:
        sql = <<-END_SQL
          SELECT r.rdb$field_name, r.rdb$field_source, f.rdb$field_type, f.rdb$field_sub_type,
                 f.rdb$field_length, f.rdb$field_precision, f.rdb$field_scale,
                 COALESCE(r.rdb$default_source, f.rdb$default_source) rdb$default_source,
                 COALESCE(r.rdb$null_flag, f.rdb$null_flag) rdb$null_flag
          FROM rdb$relation_fields r
          JOIN rdb$fields f ON r.rdb$field_source = f.rdb$field_name
          WHERE r.rdb$relation_name = '#{table_name.to_s.upcase}'
          ORDER BY r.rdb$field_position
        END_SQL
        execute(sql, name).collect do |field|
          field_values = field.values.collect do |value|
            case value
              when String         then value.rstrip
              when FireRuby::Blob then value.to_s
              else value
            end
          end
          FirebirdColumn.new(*field_values)
        end
      end

      private
        def select(sql, name = nil)
          execute(sql, name).collect do |row|
            hashed_row = {}
            row.each do |column, value|
              value = value.to_s if FireRuby::Blob === value
              hashed_row[fb_to_ar_case(column)] = value
            end
            hashed_row
          end
        end

        # Maps uppercase Firebird column names to lowercase for ActiveRecord;
        # mixed-case columns retain their original case.
        def fb_to_ar_case(column_name)
          column_name =~ /[[:lower:]]/ ? column_name : column_name.downcase
        end

        # Maps lowercase ActiveRecord column names to uppercase for Fierbird;
        # mixed-case columns retain their original case.
        def ar_to_fb_case(column_name)
          column_name =~ /[[:upper:]]/ ? column_name : column_name.upcase
        end
    end
  end
end
