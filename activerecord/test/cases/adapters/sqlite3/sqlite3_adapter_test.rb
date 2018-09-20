# frozen_string_literal: true

require "cases/helper"
require "models/owner"
require "tempfile"
require "support/ddl_helper"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3AdapterTest < ActiveRecord::SQLite3TestCase
      include DdlHelper

      self.use_transactional_tests = false

      class DualEncoding < ActiveRecord::Base
      end

      def setup
        @conn = Base.sqlite3_connection database: ":memory:",
                                        adapter: "sqlite3",
                                        timeout: 100
      end

      def test_bad_connection
        assert_raise ActiveRecord::NoDatabaseError do
          connection = ActiveRecord::Base.sqlite3_connection(adapter: "sqlite3", database: "/tmp/should/_not/_exist/-cinco-dog.db")
          connection.drop_table "ex", if_exists: true
        end
      end

      unless in_memory_db?
        def test_connect_with_url
          original_connection = ActiveRecord::Base.remove_connection
          tf = Tempfile.open "whatever"
          url = "sqlite3:#{tf.path}"
          ActiveRecord::Base.establish_connection(url)
          assert ActiveRecord::Base.connection
        ensure
          tf.close
          tf.unlink
          ActiveRecord::Base.establish_connection(original_connection)
        end

        def test_connect_memory_with_url
          original_connection = ActiveRecord::Base.remove_connection
          url = "sqlite3::memory:"
          ActiveRecord::Base.establish_connection(url)
          assert ActiveRecord::Base.connection
        ensure
          ActiveRecord::Base.establish_connection(original_connection)
        end
      end

      def test_column_types
        owner = Owner.create!(name: "hello".encode("ascii-8bit"))
        owner.reload
        select = Owner.columns.map { |c| "typeof(#{c.name})" }.join ", "
        result = Owner.connection.exec_query <<-esql
          SELECT #{select}
          FROM   #{Owner.table_name}
          WHERE  #{Owner.primary_key} = #{owner.id}
        esql

        assert_not(result.rows.first.include?("blob"), "should not store blobs")
      ensure
        owner.delete
      end

      def test_exec_insert
        with_example_table do
          vals = [Relation::QueryAttribute.new("number", 10, Type::Value.new)]
          @conn.exec_insert("insert into ex (number) VALUES (?)", "SQL", vals)

          result = @conn.exec_query(
            "select number from ex where number = ?", "SQL", vals)

          assert_equal 1, result.rows.length
          assert_equal 10, result.rows.first.first
        end
      end

      def test_primary_key_returns_nil_for_no_pk
        with_example_table "id int, data string" do
          assert_nil @conn.primary_key("ex")
        end
      end

      def test_connection_no_db
        assert_raises(ArgumentError) do
          Base.sqlite3_connection {}
        end
      end

      def test_bad_timeout
        assert_raises(TypeError) do
          Base.sqlite3_connection database: ":memory:",
                                  adapter: "sqlite3",
                                  timeout: "usa"
        end
      end

      # connection is OK with a nil timeout
      def test_nil_timeout
        conn = Base.sqlite3_connection database: ":memory:",
                                       adapter: "sqlite3",
                                       timeout: nil
        assert conn, "made a connection"
      end

      def test_connect
        assert @conn, "should have connection"
      end

      # sqlite3 defaults to UTF-8 encoding
      def test_encoding
        assert_equal "UTF-8", @conn.encoding
      end

      def test_exec_no_binds
        with_example_table "id int, data string" do
          result = @conn.exec_query("SELECT id, data FROM ex")
          assert_equal 0, result.rows.length
          assert_equal 2, result.columns.length
          assert_equal %w{ id data }, result.columns

          @conn.exec_query('INSERT INTO ex (id, data) VALUES (1, "foo")')
          result = @conn.exec_query("SELECT id, data FROM ex")
          assert_equal 1, result.rows.length
          assert_equal 2, result.columns.length

          assert_equal [[1, "foo"]], result.rows
        end
      end

      def test_exec_query_with_binds
        with_example_table "id int, data string" do
          @conn.exec_query('INSERT INTO ex (id, data) VALUES (1, "foo")')
          result = @conn.exec_query(
            "SELECT id, data FROM ex WHERE id = ?", nil, [Relation::QueryAttribute.new(nil, 1, Type::Value.new)])

          assert_equal 1, result.rows.length
          assert_equal 2, result.columns.length

          assert_equal [[1, "foo"]], result.rows
        end
      end

      def test_exec_query_typecasts_bind_vals
        with_example_table "id int, data string" do
          @conn.exec_query('INSERT INTO ex (id, data) VALUES (1, "foo")')

          result = @conn.exec_query(
            "SELECT id, data FROM ex WHERE id = ?", nil, [Relation::QueryAttribute.new("id", "1-fuu", Type::Integer.new)])

          assert_equal 1, result.rows.length
          assert_equal 2, result.columns.length

          assert_equal [[1, "foo"]], result.rows
        end
      end

      def test_quote_binary_column_escapes_it
        DualEncoding.connection.execute(<<-eosql)
          CREATE TABLE IF NOT EXISTS dual_encodings (
            id integer PRIMARY KEY AUTOINCREMENT,
            name varchar(255),
            data binary
          )
        eosql
        str = "\x80".dup.force_encoding("ASCII-8BIT")
        binary = DualEncoding.new name: "いただきます！", data: str
        binary.save!
        assert_equal str, binary.data
      ensure
        DualEncoding.connection.drop_table "dual_encodings", if_exists: true
      end

      def test_type_cast_should_not_mutate_encoding
        name = "hello".dup.force_encoding(Encoding::ASCII_8BIT)
        Owner.create(name: name)
        assert_equal Encoding::ASCII_8BIT, name.encoding
      ensure
        Owner.delete_all
      end

      def test_execute
        with_example_table do
          @conn.execute "INSERT INTO ex (number) VALUES (10)"
          records = @conn.execute "SELECT * FROM ex"
          assert_equal 1, records.length

          record = records.first
          assert_equal 10, record["number"]
          assert_equal 1, record["id"]
        end
      end

      def test_quote_string
        assert_equal "''", @conn.quote_string("'")
      end

      def test_insert_logged
        with_example_table do
          sql = "INSERT INTO ex (number) VALUES (10)"
          name = "foo"
          assert_logged [[sql, name, []]] do
            @conn.insert(sql, name)
          end
        end
      end

      def test_insert_id_value_returned
        with_example_table do
          sql = "INSERT INTO ex (number) VALUES (10)"
          idval = "vuvuzela"
          id = @conn.insert(sql, nil, nil, idval)
          assert_equal idval, id
        end
      end

      def test_select_rows
        with_example_table do
          2.times do |i|
            @conn.create "INSERT INTO ex (number) VALUES (#{i})"
          end
          rows = @conn.select_rows "select number, id from ex"
          assert_equal [[0, 1], [1, 2]], rows
        end
      end

      def test_select_rows_logged
        with_example_table do
          sql = "select * from ex"
          name = "foo"
          assert_logged [[sql, name, []]] do
            @conn.select_rows sql, name
          end
        end
      end

      def test_transaction
        with_example_table do
          count_sql = "select count(*) from ex"

          @conn.begin_db_transaction
          @conn.create "INSERT INTO ex (number) VALUES (10)"

          assert_equal 1, @conn.select_rows(count_sql).first.first
          @conn.rollback_db_transaction
          assert_equal 0, @conn.select_rows(count_sql).first.first
        end
      end

      def test_tables
        with_example_table do
          assert_equal %w{ ex }, @conn.tables
          with_example_table "id integer PRIMARY KEY AUTOINCREMENT, number integer", "people" do
            assert_equal %w{ ex people }.sort, @conn.tables.sort
          end
        end
      end

      def test_tables_logs_name
        sql = <<-SQL
          SELECT name FROM sqlite_master WHERE name <> 'sqlite_sequence' AND type IN ('table')
        SQL
        assert_logged [[sql.squish, "SCHEMA", []]] do
          @conn.tables
        end
      end

      def test_table_exists_logs_name
        with_example_table do
          sql = <<-SQL
            SELECT name FROM sqlite_master WHERE name <> 'sqlite_sequence' AND name = 'ex' AND type IN ('table')
          SQL
          assert_logged [[sql.squish, "SCHEMA", []]] do
            assert @conn.table_exists?("ex")
          end
        end
      end

      def test_columns
        with_example_table do
          columns = @conn.columns("ex").sort_by(&:name)
          assert_equal 2, columns.length
          assert_equal %w{ id number }.sort, columns.map(&:name)
          assert_equal [nil, nil], columns.map(&:default)
          assert_equal [true, true], columns.map(&:null)
        end
      end

      def test_columns_with_default
        with_example_table "id integer PRIMARY KEY AUTOINCREMENT, number integer default 10" do
          column = @conn.columns("ex").find { |x|
            x.name == "number"
          }
          assert_equal "10", column.default
        end
      end

      def test_columns_with_not_null
        with_example_table "id integer PRIMARY KEY AUTOINCREMENT, number integer not null" do
          column = @conn.columns("ex").find { |x| x.name == "number" }
          assert_not column.null, "column should not be null"
        end
      end

      def test_indexes_logs
        with_example_table do
          assert_logged [["PRAGMA index_list(\"ex\")", "SCHEMA", []]] do
            @conn.indexes("ex")
          end
        end
      end

      def test_no_indexes
        assert_equal [], @conn.indexes("items")
      end

      def test_index
        with_example_table do
          @conn.add_index "ex", "id", unique: true, name: "fun"
          index = @conn.indexes("ex").find { |idx| idx.name == "fun" }

          assert_equal "ex", index.table
          assert index.unique, "index is unique"
          assert_equal ["id"], index.columns
        end
      end

      def test_non_unique_index
        with_example_table do
          @conn.add_index "ex", "id", name: "fun"
          index = @conn.indexes("ex").find { |idx| idx.name == "fun" }
          assert_not index.unique, "index is not unique"
        end
      end

      def test_compound_index
        with_example_table do
          @conn.add_index "ex", %w{ id number }, name: "fun"
          index = @conn.indexes("ex").find { |idx| idx.name == "fun" }
          assert_equal %w{ id number }.sort, index.columns.sort
        end
      end

      if ActiveRecord::Base.connection.supports_expression_index?
        def test_expression_index
          with_example_table do
            @conn.add_index "ex", "max(id, number)", name: "expression"
            index = @conn.indexes("ex").find { |idx| idx.name == "expression" }
            assert_equal "max(id, number)", index.columns
          end
        end

        def test_expression_index_with_where
          with_example_table do
            @conn.add_index "ex", "id % 10, max(id, number)", name: "expression", where: "id > 1000"
            index = @conn.indexes("ex").find { |idx| idx.name == "expression" }
            assert_equal "id % 10, max(id, number)", index.columns
            assert_equal "id > 1000", index.where
          end
        end

        def test_complicated_expression
          with_example_table do
            @conn.execute "CREATE INDEX expression ON ex (id % 10, (CASE WHEN number > 0 THEN max(id, number) END))WHERE(id > 1000)"
            index = @conn.indexes("ex").find { |idx| idx.name == "expression" }
            assert_equal "id % 10, (CASE WHEN number > 0 THEN max(id, number) END)", index.columns
            assert_equal "(id > 1000)", index.where
          end
        end

        def test_not_everything_an_expression
          with_example_table do
            @conn.add_index "ex", "id, max(id, number)", name: "expression"
            index = @conn.indexes("ex").find { |idx| idx.name == "expression" }
            assert_equal "id, max(id, number)", index.columns
          end
        end
      end

      def test_primary_key
        with_example_table do
          assert_equal "id", @conn.primary_key("ex")
          with_example_table "internet integer PRIMARY KEY AUTOINCREMENT, number integer not null", "foos" do
            assert_equal "internet", @conn.primary_key("foos")
          end
        end
      end

      def test_no_primary_key
        with_example_table "number integer not null" do
          assert_nil @conn.primary_key("ex")
        end
      end

      class Barcode < ActiveRecord::Base
        self.primary_key = "code"
      end

      def test_copy_table_with_existing_records_have_custom_primary_key
        connection = Barcode.connection
        connection.create_table(:barcodes, primary_key: "code", id: :string, limit: 42, force: true) do |t|
          t.text :other_attr
        end
        code = "214fe0c2-dd47-46df-b53b-66090b3c1d40"
        Barcode.create!(code: code, other_attr: "xxx")

        connection.remove_column("barcodes", "other_attr")

        assert_equal code, Barcode.first.id
      ensure
        Barcode.reset_column_information
      end

      def test_copy_table_with_composite_primary_keys
        connection = Barcode.connection
        connection.create_table(:barcodes, primary_key: ["region", "code"], force: true) do |t|
          t.string :region
          t.string :code
          t.text :other_attr
        end
        region = "US"
        code = "214fe0c2-dd47-46df-b53b-66090b3c1d40"
        Barcode.create!(region: region, code: code, other_attr: "xxx")

        connection.remove_column("barcodes", "other_attr")

        assert_equal ["region", "code"], connection.primary_keys("barcodes")

        barcode = Barcode.first
        assert_equal region, barcode.region
        assert_equal code, barcode.code
      ensure
        Barcode.reset_column_information
      end

      def test_custom_primary_key_in_create_table
        connection = Barcode.connection
        connection.create_table :barcodes, id: false, force: true do |t|
          t.primary_key :id, :string
        end

        assert_equal "id", connection.primary_key("barcodes")

        custom_pk = Barcode.columns_hash["id"]

        assert_equal :string, custom_pk.type
        assert_not custom_pk.null
      ensure
        Barcode.reset_column_information
      end

      def test_custom_primary_key_in_change_table
        connection = Barcode.connection
        connection.create_table :barcodes, id: false, force: true do |t|
          t.integer :dummy
        end
        connection.change_table :barcodes do |t|
          t.primary_key :id, :string
        end

        assert_equal "id", connection.primary_key("barcodes")

        custom_pk = Barcode.columns_hash["id"]

        assert_equal :string, custom_pk.type
        assert_not custom_pk.null
      ensure
        Barcode.reset_column_information
      end

      def test_add_column_with_custom_primary_key
        connection = Barcode.connection
        connection.create_table :barcodes, id: false, force: true do |t|
          t.integer :dummy
        end
        connection.add_column :barcodes, :id, :string, primary_key: true

        assert_equal "id", connection.primary_key("barcodes")

        custom_pk = Barcode.columns_hash["id"]

        assert_equal :string, custom_pk.type
        assert_not custom_pk.null
      ensure
        Barcode.reset_column_information
      end

      def test_remove_column_preserves_partial_indexes
        connection = Barcode.connection
        connection.create_table :barcodes, force: true do |t|
          t.string :code
          t.string :region
          t.boolean :bool_attr

          t.index :code, unique: true, where: :bool_attr, name: "partial"
        end
        connection.remove_column :barcodes, :region

        index = connection.indexes("barcodes").find { |idx| idx.name == "partial" }
        assert_equal "bool_attr", index.where
      ensure
        Barcode.reset_column_information
      end

      def test_supports_extensions
        assert_not @conn.supports_extensions?, "does not support extensions"
      end

      def test_respond_to_enable_extension
        assert_respond_to @conn, :enable_extension
      end

      def test_respond_to_disable_extension
        assert_respond_to @conn, :disable_extension
      end

      def test_statement_closed
        db = ::SQLite3::Database.new(ActiveRecord::Base.
                                   configurations["arunit"]["database"])
        statement = ::SQLite3::Statement.new(db,
                                           "CREATE TABLE statement_test (number integer not null)")
        statement.stub(:step, -> { raise ::SQLite3::BusyException.new("busy") }) do
          assert_called(statement, :columns, returns: []) do
            assert_called(statement, :close) do
              ::SQLite3::Statement.stub(:new, statement) do
                assert_raises ActiveRecord::StatementInvalid do
                  @conn.exec_query "select * from statement_test"
                end
              end
            end
          end
        end
      end

      def test_deprecate_valid_alter_table_type
        assert_deprecated { @conn.valid_alter_table_type?(:string) }
      end

      def test_db_is_not_readonly_when_readonly_option_is_false
        conn = Base.sqlite3_connection database: ":memory:",
                                       adapter: "sqlite3",
                                       readonly: false

        assert_not_predicate conn.raw_connection, :readonly?
      end

      def test_db_is_not_readonly_when_readonly_option_is_unspecified
        conn = Base.sqlite3_connection database: ":memory:",
                                       adapter: "sqlite3"

        assert_not_predicate conn.raw_connection, :readonly?
      end

      def test_db_is_readonly_when_readonly_option_is_true
        conn = Base.sqlite3_connection database: ":memory:",
                                       adapter: "sqlite3",
                                       readonly: true

        assert_predicate conn.raw_connection, :readonly?
      end

      def test_writes_are_not_permitted_to_readonly_databases
        conn = Base.sqlite3_connection database: ":memory:",
                                       adapter: "sqlite3",
                                       readonly: true

        assert_raises(ActiveRecord::StatementInvalid, /SQLite3::ReadOnlyException/) do
          conn.execute("CREATE TABLE test(id integer)")
        end
      end

      private

        def assert_logged(logs)
          subscriber = SQLSubscriber.new
          subscription = ActiveSupport::Notifications.subscribe("sql.active_record", subscriber)
          yield
          assert_equal logs, subscriber.logged
        ensure
          ActiveSupport::Notifications.unsubscribe(subscription)
        end

        def with_example_table(definition = nil, table_name = "ex", &block)
          definition ||= <<-SQL
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer
          SQL
          super(@conn, table_name, definition, &block)
        end
    end
  end
end
