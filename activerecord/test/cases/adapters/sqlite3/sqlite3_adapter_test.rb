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

      class SQLiteExtensionSpec
        def self.to_path
          "/path/to/sqlite3_extension"
        end
      end

      def setup
        @conn = SQLite3Adapter.new(
          database: ":memory:",
          adapter: "sqlite3",
          timeout: 100,
        )
      end

      def test_database_should_get_created_when_missing_parent_directories_for_database_path
        dir = Dir.mktmpdir
        db_path = File.join(dir, "_not_exist/-cinco-dog.sqlite3")
        assert_nothing_raised do
          connection = SQLite3Adapter.new(adapter: "sqlite3", database: db_path)
          connection.drop_table "ex", if_exists: true
        end
        assert SQLite3Adapter.database_exists?(adapter: "sqlite3", database: db_path)
      end

      def test_database_exists_returns_false_when_the_database_does_not_exist
        assert_not SQLite3Adapter.database_exists?(adapter: "sqlite3", database: "non_extant_db"),
          "expected non_extant_db to not exist"
      end

      def test_database_exists_returns_true_when_database_exists
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        assert SQLite3Adapter.database_exists?(db_config.configuration_hash),
          "expected #{db_config.database} to exist"
      end

      unless in_memory_db?
        def test_connect_with_url
          original_connection = ActiveRecord::Base.remove_connection
          tf = Tempfile.open "whatever"
          url = "sqlite3:#{tf.path}"
          ActiveRecord::Base.establish_connection(url)
          assert ActiveRecord::Base.lease_connection
        ensure
          tf.close
          tf.unlink
          ActiveRecord::Base.establish_connection(original_connection)
        end

        def test_connect_memory_with_url
          original_connection = ActiveRecord::Base.remove_connection
          url = "sqlite3::memory:"
          ActiveRecord::Base.establish_connection(url)
          assert ActiveRecord::Base.lease_connection
        ensure
          ActiveRecord::Base.establish_connection(original_connection)
        end
      end

      def test_database_exists_returns_true_for_an_in_memory_db
        assert SQLite3Adapter.database_exists?(database: ":memory:"),
          "Expected in memory database to exist"
      end

      def test_column_types
        owner = Owner.create!(name: "hello".encode("ascii-8bit"))
        owner.reload
        select = Owner.columns.map { |c| "typeof(#{c.name})" }.join ", "
        result = Owner.lease_connection.exec_query <<~SQL
          SELECT #{select}
          FROM   #{Owner.table_name}
          WHERE  #{Owner.primary_key} = #{owner.id}
        SQL

        assert_not(result.rows.first.include?("blob"), "should not store blobs")
      ensure
        owner.delete
      end

      def test_exec_insert
        with_example_table do
          vals = [Relation::QueryAttribute.new("number", 10, Type::Value.new)]
          assert_deprecated(ActiveRecord.deprecator) do
            @conn.exec_insert("insert into ex (number) VALUES (?)", "SQL", vals)
          end

          result = @conn.exec_query(
            "select number from ex where number = ?", "SQL", vals)

          assert_equal 1, result.rows.length
          assert_equal 10, result.rows.first.first
        end
      end

      def test_exec_insert_with_quote
        with_example_table do
          vals = [Relation::QueryAttribute.new("number", 10, Type::Value.new)]
          assert_deprecated(ActiveRecord.deprecator) do
            @conn.exec_insert("insert into \"ex\" (number) VALUES (?)", "SQL", vals)
          end

          result = @conn.exec_query(
            "select number from \"ex\" where number = ?", "SQL", vals)

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
          SQLite3Adapter.new({})
        end
      end

      def test_bad_timeout
        exception = assert_raises(ActiveRecord::StatementInvalid) do
          SQLite3Adapter.new(
            database: ":memory:",
            adapter: "sqlite3",
            timeout: "usa",
          ).connect!
        end
        assert_match("TypeError", exception.message)
        assert_kind_of ActiveRecord::ConnectionAdapters::NullPool, exception.connection_pool
      end

      # connection is OK with a nil timeout
      def test_nil_timeout
        conn = SQLite3Adapter.new(
          database: ":memory:",
          adapter: "sqlite3",
          timeout: nil,
        )
        conn.connect!
        assert conn, "made a connection"
      end

      def test_connect
        assert @conn, "should have connection"
      end

      # sqlite3 defaults to UTF-8 encoding
      def test_encoding
        assert_equal "UTF-8", @conn.encoding
      end

      def test_default_pragmas
        if in_memory_db?
          assert_equal [{ "foreign_keys" => 1 }], @conn.execute("PRAGMA foreign_keys")
          assert_equal [{ "journal_mode" => "memory" }], @conn.execute("PRAGMA journal_mode")
          assert_equal [{ "synchronous" => 1 }], @conn.execute("PRAGMA synchronous")
          assert_equal [{ "journal_size_limit" => 67108864 }], @conn.execute("PRAGMA journal_size_limit")
          assert_equal [], @conn.execute("PRAGMA mmap_size")
          assert_equal [{ "cache_size" => 2000 }], @conn.execute("PRAGMA cache_size")
        else
          with_file_connection do |conn|
            assert_equal [{ "foreign_keys" => 1 }], conn.execute("PRAGMA foreign_keys")
            assert_equal [{ "journal_mode" => "wal" }], conn.execute("PRAGMA journal_mode")
            assert_equal [{ "synchronous" => 1 }], conn.execute("PRAGMA synchronous")
            assert_equal [{ "journal_size_limit" => 67108864 }], conn.execute("PRAGMA journal_size_limit")
            assert_equal [{ "mmap_size" => 134217728 }], conn.execute("PRAGMA mmap_size")
            assert_equal [{ "cache_size" => 2000 }], conn.execute("PRAGMA cache_size")
          end
        end
      end

      def test_overriding_default_foreign_keys_pragma
        method_name = in_memory_db? ? :with_memory_connection : :with_file_connection

        send(method_name, pragmas: { foreign_keys: false }) do |conn|
          assert_equal [{ "foreign_keys" => 0 }], conn.execute("PRAGMA foreign_keys")
        end

        send(method_name, pragmas: { foreign_keys: 0 }) do |conn|
          assert_equal [{ "foreign_keys" => 0 }], conn.execute("PRAGMA foreign_keys")
        end

        send(method_name, pragmas: { foreign_keys: "false" }) do |conn|
          assert_equal [{ "foreign_keys" => 0 }], conn.execute("PRAGMA foreign_keys")
        end

        error = assert_raises(ActiveRecord::StatementInvalid) do
          send(method_name, pragmas: { foreign_keys: :false }) do |conn|
            conn.execute("PRAGMA foreign_keys")
          end
        end
        assert_match(/unrecognized pragma parameter :false/, error.message)
      end

      def test_overriding_default_journal_mode_pragma
        # in-memory databases are always only ever in `memory` journal_mode
        if in_memory_db?
          with_memory_connection(pragmas: { "journal_mode" => "delete" }) do |conn|
            assert_equal [{ "journal_mode" => "memory" }], conn.execute("PRAGMA journal_mode")
          end

          with_memory_connection(pragmas: { "journal_mode" => :delete }) do |conn|
            assert_equal [{ "journal_mode" => "memory" }], conn.execute("PRAGMA journal_mode")
          end

          error = assert_raises(ActiveRecord::StatementInvalid) do
            with_memory_connection(pragmas: { "journal_mode" => 0 }) do |conn|
              conn.execute("PRAGMA journal_mode")
            end
          end
          assert_match(/nrecognized journal_mode 0/, error.message)

          error = assert_raises(ActiveRecord::StatementInvalid) do
            with_memory_connection(pragmas: { "journal_mode" => false }) do |conn|
              conn.execute("PRAGMA journal_mode")
            end
          end
          assert_match(/nrecognized journal_mode false/, error.message)
        else
          # must use a new, separate database file that hasn't been opened in WAL mode before
          Dir.mktmpdir do |tmpdir|
            database_file = File.join(tmpdir, "journal_mode_test.sqlite3")

            with_file_connection(database: database_file, pragmas: { "journal_mode" => "delete" }) do |conn|
              assert_equal [{ "journal_mode" => "delete" }], conn.execute("PRAGMA journal_mode")
            end

            with_file_connection(database: database_file, pragmas: { "journal_mode" => :delete }) do |conn|
              assert_equal [{ "journal_mode" => "delete" }], conn.execute("PRAGMA journal_mode")
            end

            error = assert_raises(ActiveRecord::StatementInvalid) do
              with_file_connection(database: database_file, pragmas: { "journal_mode" => 0 }) do |conn|
                conn.execute("PRAGMA journal_mode")
              end
            end
            assert_match(/unrecognized journal_mode 0/, error.message)

            error = assert_raises(ActiveRecord::StatementInvalid) do
              with_file_connection(database: database_file, pragmas: { "journal_mode" => false }) do |conn|
                conn.execute("PRAGMA journal_mode")
              end
            end
            assert_match(/unrecognized journal_mode false/, error.message)
          end
        end
      end

      def test_overriding_default_synchronous_pragma
        method_name = in_memory_db? ? :with_memory_connection : :with_file_connection

        send(method_name, pragmas: { synchronous: :full }) do |conn|
          assert_equal [{ "synchronous" => 2 }], conn.execute("PRAGMA synchronous")
        end

        send(method_name, pragmas: { synchronous: 2 }) do |conn|
          assert_equal [{ "synchronous" => 2 }], conn.execute("PRAGMA synchronous")
        end

        send(method_name, pragmas: { synchronous: "full" }) do |conn|
          assert_equal [{ "synchronous" => 2 }], conn.execute("PRAGMA synchronous")
        end

        error = assert_raises(ActiveRecord::StatementInvalid) do
          send(method_name, pragmas: { synchronous: false }) do |conn|
            conn.execute("PRAGMA synchronous")
          end
        end
        assert_match(/unrecognized synchronous false/, error.message)
      end

      def test_overriding_default_journal_size_limit_pragma
        method_name = in_memory_db? ? :with_memory_connection : :with_file_connection

        send(method_name, pragmas: { journal_size_limit: 100 }) do |conn|
          assert_equal [{ "journal_size_limit" => 100 }], conn.execute("PRAGMA journal_size_limit")
        end

        send(method_name, pragmas: { journal_size_limit: "200" }) do |conn|
          assert_equal [{ "journal_size_limit" => 200 }], conn.execute("PRAGMA journal_size_limit")
        end

        error = assert_raises(ActiveRecord::StatementInvalid) do
          send(method_name, pragmas: { journal_size_limit: false }) do |conn|
            conn.execute("PRAGMA journal_size_limit")
          end
        end
        assert_match(/undefined method [`']to_i'/, error.message)

        error = assert_raises(ActiveRecord::StatementInvalid) do
          send(method_name, pragmas: { journal_size_limit: :false }) do |conn|
            conn.execute("PRAGMA journal_size_limit")
          end
        end
        assert_match(/undefined method [`']to_i'/, error.message)
      end

      def test_overriding_default_mmap_size_pragma
        # in-memory databases never have an mmap_size
        if in_memory_db?
          with_memory_connection(pragmas: { mmap_size: 100 }) do |conn|
            assert_equal [], conn.execute("PRAGMA mmap_size")
          end

          with_memory_connection(pragmas: { mmap_size: "200" }) do |conn|
            assert_equal [], conn.execute("PRAGMA mmap_size")
          end

          error = assert_raises(ActiveRecord::StatementInvalid) do
            with_memory_connection(pragmas: { mmap_size: false }) do |conn|
              conn.execute("PRAGMA mmap_size")
            end
          end
          assert_match(/undefined method [`']to_i'/, error.message)

          error = assert_raises(ActiveRecord::StatementInvalid) do
            with_memory_connection(pragmas: { mmap_size: :false }) do |conn|
              conn.execute("PRAGMA mmap_size")
            end
          end
          assert_match(/undefined method [`']to_i'/, error.message)
        else
          with_file_connection(pragmas: { mmap_size: 100 }) do |conn|
            assert_equal [{ "mmap_size" => 100 }], conn.execute("PRAGMA mmap_size")
          end

          with_file_connection(pragmas: { mmap_size: "200" }) do |conn|
            assert_equal [{ "mmap_size" => 200 }], conn.execute("PRAGMA mmap_size")
          end

          error = assert_raises(ActiveRecord::StatementInvalid) do
            with_file_connection(pragmas: { mmap_size: false }) do |conn|
              conn.execute("PRAGMA mmap_size")
            end
          end
          assert_match(/undefined method [`']to_i'/, error.message)

          error = assert_raises(ActiveRecord::StatementInvalid) do
            with_file_connection(pragmas: { mmap_size: :false }) do |conn|
              conn.execute("PRAGMA mmap_size")
            end
          end
          assert_match(/undefined method [`']to_i'/, error.message)
        end
      end

      def test_overriding_default_cache_size_pragma
        method_name = in_memory_db? ? :with_memory_connection : :with_file_connection

        send(method_name, pragmas: { cache_size: 100 }) do |conn|
          assert_equal [{ "cache_size" => 100 }], conn.execute("PRAGMA cache_size")
        end

        send(method_name, pragmas: { cache_size: "200" }) do |conn|
          assert_equal [{ "cache_size" => 200 }], conn.execute("PRAGMA cache_size")
        end

        error = assert_raises(ActiveRecord::StatementInvalid) do
          send(method_name, pragmas: { cache_size: false }) do |conn|
            conn.execute("PRAGMA cache_size")
          end
        end
        assert_match(/undefined method [`']to_i'/, error.message)

        error = assert_raises(ActiveRecord::StatementInvalid) do
          send(method_name, pragmas: { cache_size: :false }) do |conn|
            conn.execute("PRAGMA cache_size")
          end
        end
        assert_match(/undefined method [`']to_i'/, error.message)
      end

      def test_setting_new_pragma
        if in_memory_db?
          with_memory_connection(pragmas: { temp_store: :memory }) do |conn|
            assert_equal [{ "foreign_keys" => 1 }], conn.execute("PRAGMA foreign_keys")
            assert_equal [{ "journal_mode" => "memory" }], conn.execute("PRAGMA journal_mode")
            assert_equal [{ "synchronous" => 1 }], conn.execute("PRAGMA synchronous")
            assert_equal [{ "journal_size_limit" => 67108864 }], conn.execute("PRAGMA journal_size_limit")
            assert_equal [], conn.execute("PRAGMA mmap_size")
            assert_equal [{ "cache_size" => 2000 }], conn.execute("PRAGMA cache_size")
            assert_equal [{ "temp_store" => 2 }], conn.execute("PRAGMA temp_store")
          end
        else
          with_file_connection(pragmas: { temp_store: :memory }) do |conn|
            assert_equal [{ "foreign_keys" => 1 }], conn.execute("PRAGMA foreign_keys")
            assert_equal [{ "journal_mode" => "wal" }], conn.execute("PRAGMA journal_mode")
            assert_equal [{ "synchronous" => 1 }], conn.execute("PRAGMA synchronous")
            assert_equal [{ "journal_size_limit" => 67108864 }], conn.execute("PRAGMA journal_size_limit")
            assert_equal [{ "mmap_size" => 134217728 }], conn.execute("PRAGMA mmap_size")
            assert_equal [{ "cache_size" => 2000 }], conn.execute("PRAGMA cache_size")
            assert_equal [{ "temp_store" => 2 }], conn.execute("PRAGMA temp_store")
          end
        end
      end

      def test_setting_invalid_pragma
        if in_memory_db?
          warning = capture(:stderr) do
            with_memory_connection(pragmas: { invalid: true }) do |conn|
              conn.execute("PRAGMA foreign_keys")
            end
          end
          assert_match(/Unknown SQLite pragma: invalid/, warning)
        else
          warning = capture(:stderr) do
            with_file_connection(pragmas: { invalid: true }) do |conn|
              conn.execute("PRAGMA foreign_keys")
            end
          end
          assert_match(/Unknown SQLite pragma: invalid/, warning)
        end
      end

      def test_exec_no_binds
        with_example_table "id int, data string" do
          result = @conn.exec_query("SELECT id, data FROM ex")
          assert_equal 0, result.rows.length
          assert_equal 2, result.columns.length
          assert_equal %w{ id data }, result.columns

          @conn.exec_query("INSERT INTO ex (id, data) VALUES (1, 'foo')")
          result = @conn.exec_query("SELECT id, data FROM ex")
          assert_equal 1, result.rows.length
          assert_equal 2, result.columns.length

          assert_equal [[1, "foo"]], result.rows
        end
      end

      def test_exec_query_with_binds
        with_example_table "id int, data string" do
          @conn.exec_query("INSERT INTO ex (id, data) VALUES (1, 'foo')")
          result = @conn.exec_query(
            "SELECT id, data FROM ex WHERE id = ?", nil, [Relation::QueryAttribute.new(nil, 1, Type::Value.new)])

          assert_equal 1, result.rows.length
          assert_equal 2, result.columns.length

          assert_equal [[1, "foo"]], result.rows
        end
      end

      def test_exec_query_typecasts_bind_vals
        with_example_table "id int, data string" do
          @conn.exec_query("INSERT INTO ex (id, data) VALUES (1, 'foo')")

          result = @conn.exec_query(
            "SELECT id, data FROM ex WHERE id = ?", nil, [Relation::QueryAttribute.new("id", "1-fuu", Type::Integer.new)])

          assert_equal 1, result.rows.length
          assert_equal 2, result.columns.length

          assert_equal [[1, "foo"]], result.rows
        end
      end

      def test_quote_binary_column_escapes_it
        DualEncoding.lease_connection.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS dual_encodings (
            id integer PRIMARY KEY AUTOINCREMENT,
            name varchar(255),
            data binary
          )
        SQL
        str = (+"\x80").force_encoding("ASCII-8BIT")
        binary = DualEncoding.new name: "いただきます！", data: str
        binary.save!
        assert_equal str, binary.data
      ensure
        DualEncoding.lease_connection.drop_table "dual_encodings", if_exists: true
      end

      def test_type_cast_should_not_mutate_encoding
        name = (+"hello").force_encoding(Encoding::ASCII_8BIT)
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

      def test_insert_logged
        with_example_table do
          sql = "INSERT INTO ex (number) VALUES (10)"
          name = "foo"

          tables_query = ["SELECT name FROM pragma_table_list WHERE schema <> 'temp' AND name NOT IN ('sqlite_sequence', 'sqlite_schema') AND type IN ('table','view')", "SCHEMA", []]
          pragma_query = ["PRAGMA table_xinfo(\"ex\")", "SCHEMA", []]
          schema_query = ["SELECT sql FROM (SELECT * FROM sqlite_master UNION ALL SELECT * FROM sqlite_temp_master) WHERE type = 'table' AND name = 'ex'", "SCHEMA", []]
          modified_insert_query = [(sql + ' RETURNING "id"'), name, []]

          # First insert after with_example_table has reset the schema cache
          assert_logged [tables_query, pragma_query, schema_query, modified_insert_query] do
            @conn.insert(sql, name)
          end

          # Subsequent inserts don't need extra schema queries
          assert_logged [modified_insert_query] do
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

      def test_exec_insert_with_returning_disabled
        original_conn = @conn
        @conn = SQLite3Adapter.new(
          database: ":memory:",
          adapter: "sqlite3",
          insert_returning: false,
        )
        with_example_table do
          result = assert_deprecated(ActiveRecord.deprecator) do
            @conn.exec_insert("insert into ex (number) VALUES ('foo')", nil, [], "id")
          end
          expect = @conn.select_value("select max(id) from ex")
          assert_equal expect.to_i, result.rows.first.first
        end
        @conn = original_conn
      end

      def test_exec_insert_default_values_with_returning_disabled
        original_conn = @conn
        @conn = SQLite3Adapter.new(
          database: ":memory:",
          adapter: "sqlite3",
          insert_returning: false,
        )
        with_example_table do
          result = assert_deprecated(ActiveRecord.deprecator) do
            @conn.exec_insert("insert into ex DEFAULT VALUES", nil, [], "id")
          end
          expect = @conn.select_value("select max(id) from ex")
          assert_equal expect.to_i, result.rows.first.first
        end
        @conn = original_conn
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
        sql = <<~SQL
          SELECT name FROM pragma_table_list WHERE schema <> 'temp' AND name NOT IN ('sqlite_sequence', 'sqlite_schema') AND type IN ('table')
        SQL
        @conn.connect!
        assert_logged [[sql.squish, "SCHEMA", []]] do
          @conn.tables
        end
      end

      def test_table_exists_logs_name
        with_example_table do
          sql = <<~SQL
            SELECT name FROM pragma_table_list WHERE schema <> 'temp' AND name NOT IN ('sqlite_sequence', 'sqlite_schema') AND name = 'ex' AND type IN ('table')
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
          assert_equal 10, column.default
        end
      end

      def test_columns_with_not_null
        with_example_table "id integer PRIMARY KEY AUTOINCREMENT, number integer not null" do
          column = @conn.columns("ex").find { |x| x.name == "number" }
          assert_not column.null, "column should not be null"
        end
      end

      def test_add_column_with_not_null
        with_example_table "id integer PRIMARY KEY AUTOINCREMENT, number integer not null" do
          assert_nothing_raised { @conn.add_column :ex, :name, :string, null: false }
          column = @conn.columns("ex").find { |x| x.name == "name" }
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

      def test_index_with_if_not_exists
        with_example_table do
          @conn.add_index "ex", "id"

          assert_nothing_raised do
            @conn.add_index "ex", "id", if_not_exists: true
          end
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

      def test_partial_index_with_comment
        with_example_table do
          @conn.add_index "ex", :id, name: "fun", where: "number > 0 /*tag:test*/"
          index = @conn.indexes("ex").find { |idx| idx.name == "fun" }
          assert_equal ["id"], index.columns
          assert_equal "number > 0", index.where
        end
      end

      if ActiveRecord::Base.lease_connection.supports_expression_index?
        def test_expression_index
          with_example_table do
            @conn.add_index "ex", "max(id, number)", name: "expression"
            index = @conn.indexes("ex").find { |idx| idx.name == "expression" }
            assert_equal "max(id, number)", index.columns
          end
        end

        def test_expression_index_with_trailing_comment
          with_example_table do
            @conn.execute "CREATE INDEX expression on ex (number % 10) /* comment */"
            index = @conn.indexes("ex").find { |idx| idx.name == "expression" }
            assert_equal "number % 10", index.columns
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
      end

      class BarcodeCustomPk < ActiveRecord::Base
        self.primary_key = "code"
      end

      def test_copy_table_with_existing_records_have_custom_primary_key
        connection = BarcodeCustomPk.lease_connection
        connection.create_table(:barcode_custom_pks, primary_key: "code", id: :string, limit: 42, force: true) do |t|
          t.text :other_attr
        end
        code = "214fe0c2-dd47-46df-b53b-66090b3c1d40"
        BarcodeCustomPk.create!(code: code, other_attr: "xxx")

        connection.remove_column("barcode_custom_pks", "other_attr")

        assert_equal code, BarcodeCustomPk.first.id
      ensure
        BarcodeCustomPk.reset_column_information
      end

      class BarcodeCpk < ActiveRecord::Base
        self.primary_key = ["region", "code"]
      end

      def test_copy_table_with_composite_primary_keys
        connection = BarcodeCpk.lease_connection
        connection.create_table(:barcode_cpks, primary_key: ["region", "code"], force: true) do |t|
          t.string :region
          t.string :code
          t.text :other_attr
        end
        region = "US"
        code = "214fe0c2-dd47-46df-b53b-66090b3c1d40"
        BarcodeCpk.create!(region: region, code: code, other_attr: "xxx")

        connection.remove_column("barcode_cpks", "other_attr")

        assert_equal ["region", "code"], connection.primary_keys("barcode_cpks")

        barcode = BarcodeCpk.first
        assert_equal region, barcode.region
        assert_equal code, barcode.code
      ensure
        BarcodeCpk.reset_column_information
      end

      def test_custom_primary_key_in_create_table
        connection = Barcode.lease_connection
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
        connection = Barcode.lease_connection
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
        connection = Barcode.lease_connection
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

      def test_remove_column_preserves_index_options
        connection = Barcode.lease_connection
        connection.create_table :barcodes, force: true do |t|
          t.string :code
          t.string :region
          t.boolean :bool_attr

          t.index :code, unique: true, name: "unique"
          t.index :code, where: :bool_attr, name: "partial"
          t.index :code, name: "ordered", order: { code: :desc }
        end
        connection.remove_column :barcodes, :region

        indexes = connection.indexes("barcodes")

        partial_index = indexes.find { |idx| idx.name == "partial" }
        assert_equal "bool_attr", partial_index.where

        unique_index = indexes.find { |idx| idx.name == "unique" }
        assert unique_index.unique

        ordered_index = indexes.find { |idx| idx.name == "ordered" }
        assert_equal :desc, ordered_index.orders
      ensure
        Barcode.reset_column_information
      end

      def test_auto_increment_preserved_on_table_changes
        connection = Barcode.lease_connection
        connection.create_table :barcodes, force: true do |t|
          t.string :code
        end

        pk_column = connection.columns("barcodes").find { |col| col.name == "id" }
        sql = connection.exec_query("SELECT sql FROM sqlite_master WHERE tbl_name='barcodes'").rows.first.first

        assert_predicate(pk_column, :auto_increment?)
        assert(sql.match?("PRIMARY KEY AUTOINCREMENT"))

        connection.change_column(:barcodes, :code, :integer)

        pk_column = connection.columns("barcodes").find { |col| col.name == "id" }
        sql = connection.exec_query("SELECT sql FROM sqlite_master WHERE tbl_name='barcodes'").rows.first.first

        assert_predicate(pk_column, :auto_increment?)
        assert(sql.match?("PRIMARY KEY AUTOINCREMENT"))
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
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        db = ::SQLite3::Database.new(db_config.database)

        @conn.connect!

        statement = ::SQLite3::Statement.new(db,
                                           "CREATE TABLE statement_test (number integer not null)")
        statement.stub(:step, -> { raise ::SQLite3::BusyException.new("busy") }) do
          assert_called(statement, :close) do
            ::SQLite3::Statement.stub(:new, statement) do
              error = assert_raises ActiveRecord::StatementTimeout do
                @conn.exec_query "select * from statement_test"
              end
              assert_equal @conn.pool, error.connection_pool
            end
          end
        end
      end

      def test_db_is_not_readonly_when_readonly_option_is_false
        conn = SQLite3Adapter.new(
          database: ":memory:",
          adapter: "sqlite3",
          readonly: false,
        )
        conn.connect!

        assert_not_predicate conn.raw_connection, :readonly?
      end

      def test_db_is_not_readonly_when_readonly_option_is_unspecified
        conn = SQLite3Adapter.new(
          database: ":memory:",
          adapter: "sqlite3",
        )
        conn.connect!

        assert_not_predicate conn.raw_connection, :readonly?
      end

      def test_db_is_readonly_when_readonly_option_is_true
        conn = SQLite3Adapter.new(
          database: ":memory:",
          adapter: "sqlite3",
          readonly: true,
        )
        conn.connect!

        assert_predicate conn.raw_connection, :readonly?
      end

      def test_writes_are_not_permitted_to_readonly_databases
        conn = SQLite3Adapter.new(
          database: ":memory:",
          adapter: "sqlite3",
          readonly: true,
        )
        conn.connect!

        exception = assert_raises(ActiveRecord::StatementInvalid) do
          conn.execute("CREATE TABLE test(id integer)")
        end
        assert_match("SQLite3::ReadOnlyException", exception.message)
        assert_equal conn.pool, exception.connection_pool
      end

      def test_strict_strings_by_default
        conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3")
        conn.create_table :testings

        assert_nothing_raised do
          conn.add_index :testings, :non_existent
        end

        with_strict_strings_by_default do
          conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3")
          conn.create_table :testings

          error = assert_raises(StandardError) do
            conn.add_index :testings, :non_existent2
          end
          assert_match(/no such column: "?non_existent2"?/, error.message)
          assert_equal conn.pool, error.connection_pool
        end
      end

      def test_strict_strings_by_default_and_true_in_database_yml
        conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3", strict: true)
        conn.create_table :testings

        error = assert_raises(StandardError) do
          conn.add_index :testings, :non_existent
        end
        assert_match(/no such column: "?non_existent"?/, error.message)
        assert_equal conn.pool, error.connection_pool

        with_strict_strings_by_default do
          conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3", strict: true)
          conn.create_table :testings

          error = assert_raises(StandardError) do
            conn.add_index :testings, :non_existent2
          end
          assert_match(/no such column: "?non_existent2"?/, error.message)
          assert_equal conn.pool, error.connection_pool
        end
      end

      def test_strict_strings_by_default_and_false_in_database_yml
        conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3", strict: false)
        conn.create_table :testings

        assert_nothing_raised do
          conn.add_index :testings, :non_existent
        end

        with_strict_strings_by_default do
          conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3", strict: false)
          conn.create_table :testings

          assert_nothing_raised do
            conn.add_index :testings, :non_existent
          end
        end
      end

      def test_rowid_column
        with_example_table "id_uppercase INTEGER PRIMARY KEY" do
          assert @conn.columns("ex").index_by(&:name)["id_uppercase"].rowid
        end
      end

      def test_lowercase_rowid_column
        with_example_table "id_lowercase integer PRIMARY KEY" do
          assert @conn.columns("ex").index_by(&:name)["id_lowercase"].rowid
        end
      end

      def test_non_integer_column_returns_false_for_rowid
        with_example_table "id_int_short int PRIMARY KEY" do
          assert_not @conn.columns("ex").index_by(&:name)["id_int_short"].rowid
        end
      end

      def test_mixed_case_integer_column_returns_true_for_rowid
        with_example_table "id_mixed_case InTeGeR PRIMARY KEY" do
          assert @conn.columns("ex").index_by(&:name)["id_mixed_case"].rowid
        end
      end

      def test_rowid_column_with_autoincrement_returns_true_for_rowid
        with_example_table "id_autoincrement integer PRIMARY KEY AUTOINCREMENT" do
          assert @conn.columns("ex").index_by(&:name)["id_autoincrement"].rowid
        end
      end

      def test_integer_cpk_column_returns_false_for_rowid
        with_example_table("id integer, shop_id integer, PRIMARY KEY (shop_id, id)", "cpk_table") do
          assert_not @conn.columns("cpk_table").any?(&:rowid)
        end
      end

      def test_rowid_changes_column_equality
        cast_type = @conn.lookup_cast_type("integer")
        type_metadata = SqlTypeMetadata.new(sql_type: "integer", type: :integer)

        rowid_column = SQLite3::Column.new("id", cast_type, nil, type_metadata, true, nil, rowid: true)
        regular_column = SQLite3::Column.new("id", cast_type, nil, type_metadata, true, nil, rowid: false)

        assert_not_equal rowid_column, regular_column
      end

      def test_sqlite_extensions_are_constantized_for_the_client_constructor
        mock_adapter = Class.new(SQLite3Adapter) do
          class << self
            attr_reader :new_client_arg

            def new_client(config)
              @new_client_arg = config
            end
          end
        end

        conn = mock_adapter.new({
          database: ":memory:",
          adapter: "sqlite3",
          extensions: [
            "/string/literal/path",
            "ActiveRecord::ConnectionAdapters::SQLite3AdapterTest::SQLiteExtensionSpec",
          ]
        })
        conn.send(:connect)

        assert_equal(["/string/literal/path", SQLiteExtensionSpec], conn.class.new_client_arg[:extensions])
      end

      test "path resolution of a relative file path" do
        database = "storage/production/main.sqlite3"
        assert_equal("storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
        assert_equal("/foo/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))

        with_rails_root do
          assert_equal("/app/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
          assert_equal("/foo/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))
        end
      end

      test "path resolution of an absolute file path" do
        database = "/var/storage/production/main.sqlite3"
        assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
        assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))

        with_rails_root do
          assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
          assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))
        end
      end

      test "path resolution of an absolute URI" do
        database = "file:/var/storage/production/main.sqlite3"
        assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
        assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))

        with_rails_root do
          assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
          assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))
        end
      end

      test "path resolution of an absolute URI with query params" do
        database = "file:/var/storage/production/main.sqlite3?vfs=unix-dotfile"
        assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
        assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))

        with_rails_root do
          assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
          assert_equal("/var/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))
        end
      end

      test "path resolution of a relative URI" do
        database = "file:storage/production/main.sqlite3"
        assert_equal("storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
        assert_equal("/foo/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))

        with_rails_root do
          assert_equal("/app/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
          assert_equal("/foo/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))
        end
      end

      test "path resolution of a relative URI with query params" do
        database = "file:storage/production/main.sqlite3?vfs=unix-dotfile"
        assert_equal("storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
        assert_equal("/foo/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))

        with_rails_root do
          assert_equal("/app/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database))
          assert_equal("/foo/storage/production/main.sqlite3", SQLite3Adapter.resolve_path(database, root: "/foo"))
        end
      end

      def test_alter_table_with_fk_preserves_rows_when_referenced_table_altered
        conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3", strict: false)

        conn.create_table :authors do |t|
          t.string :name, null: false
        end

        conn.create_table :books do |t|
          t.string  :title, null: false
          t.integer :author_id, null: false
        end
        conn.add_foreign_key :books, :authors, on_delete: :cascade

        conn.execute("INSERT INTO authors (id, name) VALUES (1, 'Douglas Adams');")
        conn.execute("INSERT INTO books (id, title, author_id) VALUES (42, 'The Hitchhiker''s Guide', 1);")
        conn.execute("INSERT INTO books (id, title, author_id) VALUES (43, 'Restaurant at the End', 1);")

        initial_book_count = conn.select_value("SELECT COUNT(*) FROM books")
        assert_equal 2, initial_book_count

        conn.add_column :authors, :email, :string

        book_count = conn.select_value("SELECT COUNT(*) FROM books")
        author_count = conn.select_value("SELECT COUNT(*) FROM authors")

        assert_equal 2, book_count, "Books were CASCADE deleted when authors table was altered!"
        assert_equal 1, author_count, "Authors were lost during table alteration!"
      ensure
        conn.disconnect! if conn
      end

      def test_alter_table_with_fk_preserves_rows_when_adding_fk_to_referenced_table
        conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3", strict: false)

        conn.create_table :groups do |t|
          t.string :name, null: false
        end

        conn.create_table :users do |t|
          t.string :username, null: false
        end

        conn.create_table :reports do |t|
          t.string  :title, null: false
          t.integer :group_id, null: false
        end
        conn.add_foreign_key :reports, :groups, on_delete: :cascade

        conn.execute("INSERT INTO groups (id, name) VALUES (1, 'Admin Group');")
        conn.execute("INSERT INTO users (id, username) VALUES (1, 'alice');")
        conn.execute("INSERT INTO reports (id, title, group_id) VALUES (1, 'Report A', 1);")
        conn.execute("INSERT INTO reports (id, title, group_id) VALUES (2, 'Report B', 1);")

        initial_report_count = conn.select_value("SELECT COUNT(*) FROM reports")
        assert_equal 2, initial_report_count

        conn.add_column :groups, :owner_id, :integer
        conn.add_foreign_key :groups, :users, column: :owner_id

        report_count = conn.select_value("SELECT COUNT(*) FROM reports")
        group_count = conn.select_value("SELECT COUNT(*) FROM groups")

        assert_equal 2, report_count, "Reports were CASCADE deleted when groups table was altered!"
        assert_equal 1, group_count, "Groups were lost during table alteration!"
      ensure
        conn.disconnect! if conn
      end

      def test_alter_table_with_multiple_cascade_fks_preserves_all_data
        conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3", strict: false)

        conn.create_table :authors do |t|
          t.string :name, null: false
        end

        conn.create_table :books do |t|
          t.string  :title, null: false
          t.integer :author_id, null: false
        end
        conn.add_foreign_key :books, :authors, on_delete: :cascade

        conn.create_table :articles do |t|
          t.string  :headline, null: false
          t.integer :author_id, null: false
        end
        conn.add_foreign_key :articles, :authors, on_delete: :cascade

        conn.execute("INSERT INTO authors (id, name) VALUES (1, 'Douglas Adams');")
        conn.execute("INSERT INTO books (id, title, author_id) VALUES (1, 'HHGTTG', 1);")
        conn.execute("INSERT INTO articles (id, headline, author_id) VALUES (1, 'Towel Day', 1);")

        conn.add_column :authors, :bio, :text

        book_count = conn.select_value("SELECT COUNT(*) FROM books")
        article_count = conn.select_value("SELECT COUNT(*) FROM articles")

        assert_equal 1, book_count, "Books were CASCADE deleted when authors table was altered!"
        assert_equal 1, article_count, "Articles were CASCADE deleted when authors table was altered!"
      ensure
        conn.disconnect! if conn
      end

      def test_rename_table_with_cascade_fk_preserves_referencing_data
        conn = SQLite3Adapter.new(database: ":memory:", adapter: "sqlite3", strict: false)

        conn.create_table :authors do |t|
          t.string :name, null: false
        end

        conn.create_table :books do |t|
          t.string  :title, null: false
          t.integer :author_id, null: false
        end
        conn.add_foreign_key :books, :authors, on_delete: :cascade

        conn.execute("INSERT INTO authors (id, name) VALUES (1, 'Douglas Adams');")
        conn.execute("INSERT INTO books (id, title, author_id) VALUES (1, 'HHGTTG', 1);")

        conn.rename_table :authors, :writers

        book_count = conn.select_value("SELECT COUNT(*) FROM books")
        assert_equal 1, book_count, "Books were CASCADE deleted when authors table was renamed!"
      ensure
        conn.disconnect! if conn
      end

      private
        def with_rails_root(&block)
          mod = Module.new do
            def self.root
              Pathname.new("/app")
            end
          end
          stub_const(Object, :Rails, mod, &block)
        end

        def assert_logged(logs)
          subscriber = SQLSubscriber.new
          subscription = ActiveSupport::Notifications.subscribe("sql.active_record", subscriber)
          yield
          assert_equal logs, subscriber.logged
        ensure
          ActiveSupport::Notifications.unsubscribe(subscription)
        end

        def with_example_table(definition = nil, table_name = "ex", &block)
          definition ||= <<~SQL
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer
          SQL
          super(@conn, table_name, definition, &block)
        end

        def with_strict_strings_by_default
          SQLite3Adapter.strict_strings_by_default = true
          yield
        ensure
          SQLite3Adapter.strict_strings_by_default = false
        end

        def with_file_connection(options = {})
          options = options.dup
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit2", name: "primary")
          options[:database] ||= db_config.database
          conn = SQLite3Adapter.new(options)

          yield(conn)
        ensure
          conn.disconnect! if conn
        end

        def with_memory_connection(options = {})
          options = options.dup
          options[:database] = ":memory:"
          conn = SQLite3Adapter.new(options)

          yield(conn)
        ensure
          conn.disconnect! if conn
        end
    end
  end
end
