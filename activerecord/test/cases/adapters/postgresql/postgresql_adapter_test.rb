# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"
require "support/connection_helper"

require "active_support/error_reporter/test_helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::PostgreSQLTestCase
      self.use_transactional_tests = false
      include DdlHelper
      include ConnectionHelper

      def setup
        @connection = ActiveRecord::Base.lease_connection
        @original_db_warnings_action = :ignore
      end

      def test_connection_error
        error = assert_raises ActiveRecord::ConnectionNotEstablished do
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(host: File::NULL).connect!
        end
        assert_kind_of ActiveRecord::ConnectionAdapters::NullPool, error.connection_pool
      end

      def test_reconnection_error
        fake_connection = Class.new do
          def async_exec(*)
            [{}]
          end

          def type_map_for_queries=(_)
          end

          def type_map_for_results=(_)
          end

          def exec_params(*)
            {}
          end

          def escape(query)
            PG::Connection.escape(query)
          end

          def reset
            raise PG::ConnectionBad, "I'll be rescued by the reconnect method"
          end

          def close
          end
        end.new

        @conn = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(
          fake_connection,
          ActiveRecord::Base.logger,
          nil,
          { host: File::NULL }
        )

        connect_raises_error = proc { |**_conn_params| raise(PG::ConnectionBad, "actual bad connection error") }
        PG.stub(:connect, connect_raises_error) do
          error = assert_raises ActiveRecord::ConnectionNotEstablished do
            @conn.reconnect!
          end

          assert_equal("actual bad connection error", error.message)
          assert_equal @conn.pool, error.connection_pool
        end
      end

      def test_bad_connection
        assert_raise ActiveRecord::NoDatabaseError do
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
          configuration = db_config.configuration_hash.merge(database: "should_not_exist-cinco-dog-db")
          connection = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(configuration)
          connection.exec_query("SELECT 1")
        end
      end

      def test_bad_connection_to_postgres_database
        connect_raises_error = proc { |**_conn_params| raise(PG::ConnectionBad, 'FATAL:  database "postgres" does not exist') }
        PG.stub(:connect, connect_raises_error) do
          connection = nil
          error = assert_raises ActiveRecord::ConnectionNotEstablished do
            db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
            configuration = db_config.configuration_hash.merge(database: "postgres")
            connection = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(configuration)
            connection.exec_query("SELECT 1")
          end
          assert_not_nil connection
          assert_equal connection.pool, error.connection_pool
        end
      end

      def test_database_exists_returns_false_when_the_database_does_not_exist
        config = { database: "non_extant_database", adapter: "postgresql" }
        assert_not ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.database_exists?(config),
          "expected database #{config[:database]} to not exist"
      end

      def test_database_exists_returns_true_when_the_database_exists
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        assert ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.database_exists?(db_config.configuration_hash),
          "expected database #{db_config.database} to exist"
      end

      def test_primary_key
        with_example_table do
          assert_equal "id", @connection.primary_key("ex")
        end
      end

      def test_primary_key_works_tables_containing_capital_letters
        assert_equal "id", @connection.primary_key("CamelCase")
      end

      def test_non_standard_primary_key
        with_example_table "data character varying(255) primary key" do
          assert_equal "data", @connection.primary_key("ex")
        end
      end

      def test_primary_key_returns_nil_for_no_pk
        with_example_table "id integer" do
          assert_nil @connection.primary_key("ex")
        end
      end

      def test_exec_insert_with_returning_disabled
        connection = connection_without_insert_returning
        result = connection.exec_insert("insert into postgresql_partitioned_table_parent (number) VALUES (1)", nil, [], "id", "postgresql_partitioned_table_parent_id_seq")
        expect = connection.query("select max(id) from postgresql_partitioned_table_parent").first.first
        assert_equal expect.to_i, result.rows.first.first
      end

      def test_exec_insert_with_returning_disabled_and_no_sequence_name_given
        connection = connection_without_insert_returning
        result = connection.exec_insert("insert into postgresql_partitioned_table_parent (number) VALUES (1)", nil, [], "id")
        expect = connection.query("select max(id) from postgresql_partitioned_table_parent").first.first
        assert_equal expect.to_i, result.rows.first.first
      end

      def test_exec_insert_default_values_with_returning_disabled_and_no_sequence_name_given
        connection = connection_without_insert_returning
        result = connection.exec_insert("insert into postgresql_partitioned_table_parent DEFAULT VALUES", nil, [], "id")
        expect = connection.query("select max(id) from postgresql_partitioned_table_parent").first.first
        assert_equal expect.to_i, result.rows.first.first
      end

      def test_exec_insert_default_values_quoted_schema_with_returning_disabled_and_no_sequence_name_given
        connection = connection_without_insert_returning
        result = connection.exec_insert('insert into "public"."postgresql_partitioned_table_parent" DEFAULT VALUES', nil, [], "id")
        expect = connection.query("select max(id) from postgresql_partitioned_table_parent").first.first
        assert_equal expect.to_i, result.rows.first.first
      end

      def test_serial_sequence
        assert_equal "public.accounts_id_seq",
          @connection.serial_sequence("accounts", "id")

        error = assert_raises(ActiveRecord::StatementInvalid) do
          @connection.serial_sequence("zomg", "id")
        end

        assert_equal @connection.pool, error.connection_pool
      end

      def test_default_sequence_name
        assert_equal "public.accounts_id_seq",
          @connection.default_sequence_name("accounts", "id")

        assert_equal "public.accounts_id_seq",
          @connection.default_sequence_name("accounts")
      end

      def test_default_sequence_name_bad_table
        assert_equal "zomg_id_seq",
          @connection.default_sequence_name("zomg", "id")

        assert_equal "zomg_id_seq",
          @connection.default_sequence_name("zomg")
      end

      def test_pk_and_sequence_for
        with_example_table do
          pk, seq = @connection.pk_and_sequence_for("ex")
          assert_equal "id", pk
          assert_equal @connection.default_sequence_name("ex", "id"), seq.to_s
        end
      end

      def test_pk_and_sequence_for_with_non_standard_primary_key
        with_example_table "code serial primary key" do
          pk, seq = @connection.pk_and_sequence_for("ex")
          assert_equal "code", pk
          assert_equal @connection.default_sequence_name("ex", "code"), seq.to_s
        end
      end

      def test_pk_and_sequence_for_returns_nil_if_no_seq
        with_example_table "id integer primary key" do
          assert_nil @connection.pk_and_sequence_for("ex")
        end
      end

      def test_pk_and_sequence_for_returns_nil_if_no_pk
        with_example_table "id integer" do
          assert_nil @connection.pk_and_sequence_for("ex")
        end
      end

      def test_pk_and_sequence_for_returns_nil_if_table_not_found
        assert_nil @connection.pk_and_sequence_for("unobtainium")
      end

      def test_pk_and_sequence_for_with_collision_pg_class_oid
        @connection.exec_query("create table ex(id serial primary key)")
        @connection.exec_query("create table ex2(id serial primary key)")

        correct_depend_record = [
          "'pg_class'::regclass",
          "'ex_id_seq'::regclass",
          "0",
          "'pg_class'::regclass",
          "'ex'::regclass",
          "1",
          "'a'"
        ]

        collision_depend_record = [
          "'pg_attrdef'::regclass",
          "'ex2_id_seq'::regclass",
          "0",
          "'pg_class'::regclass",
          "'ex'::regclass",
          "1",
          "'a'"
        ]

        @connection.exec_query(
          "DELETE FROM pg_depend WHERE objid = 'ex_id_seq'::regclass AND refobjid = 'ex'::regclass AND deptype = 'a'"
        )
        @connection.exec_query(
          "INSERT INTO pg_depend VALUES(#{collision_depend_record.join(',')})"
        )
        @connection.exec_query(
          "INSERT INTO pg_depend VALUES(#{correct_depend_record.join(',')})"
        )

        seq = @connection.pk_and_sequence_for("ex").last
        assert_equal PostgreSQL::Name.new("public", "ex_id_seq"), seq

        @connection.exec_query(
          "DELETE FROM pg_depend WHERE objid = 'ex2_id_seq'::regclass AND refobjid = 'ex'::regclass AND deptype = 'a'"
        )
      ensure
        @connection.drop_table "ex", if_exists: true
        @connection.drop_table "ex2", if_exists: true
      end

      def test_table_alias_length
        assert_nothing_raised do
          @connection.table_alias_length
        end
      end

      def test_exec_no_binds
        with_example_table do
          result = @connection.exec_query("SELECT id, data FROM ex")
          assert_equal 0, result.rows.length
          assert_equal 2, result.columns.length
          assert_equal %w{ id data }, result.columns

          string = @connection.quote("foo")
          @connection.exec_query("INSERT INTO ex (id, data) VALUES (1, #{string})")
          result = @connection.exec_query("SELECT id, data FROM ex")
          assert_equal 1, result.rows.length
          assert_equal 2, result.columns.length

          assert_equal [[1, "foo"]], result.rows
        end
      end

      def test_exec_with_binds
        with_example_table do
          string = @connection.quote("foo")
          @connection.exec_query("INSERT INTO ex (id, data) VALUES (1, #{string})")

          bind = Relation::QueryAttribute.new("id", 1, Type::Value.new)
          result = @connection.exec_query("SELECT id, data FROM ex WHERE id = $1", nil, [bind])

          assert_equal 1, result.rows.length
          assert_equal 2, result.columns.length

          assert_equal [[1, "foo"]], result.rows
        end
      end

      def test_exec_typecasts_bind_vals
        with_example_table do
          string = @connection.quote("foo")
          @connection.exec_query("INSERT INTO ex (id, data) VALUES (1, #{string})")

          bind = Relation::QueryAttribute.new("id", "1-fuu", Type::Integer.new)
          result = @connection.exec_query("SELECT id, data FROM ex WHERE id = $1", nil, [bind])

          assert_equal 1, result.rows.length
          assert_equal 2, result.columns.length

          assert_equal [[1, "foo"]], result.rows
        end
      end

      def test_partial_index
        with_example_table do
          @connection.add_index "ex", %w{ id number }, name: "partial", where: "number > 100"
          index = @connection.indexes("ex").find { |idx| idx.name == "partial" }
          assert_equal "(number > 100)", index.where
        end
      end

      def test_partial_index_on_column_named_like_keyword
        with_example_table('id serial primary key, number integer, "primary" boolean') do
          @connection.add_index "ex", "id", name: "partial", where: "primary" # "primary" is a keyword
          index = @connection.indexes("ex").find { |idx| idx.name == "partial" }
          assert_equal '"primary"', index.where
        end
      end

      if supports_index_include?
        def test_include_index
          with_example_table do
            @connection.add_index "ex", %w{ id }, name: "include", include: :number
            index = @connection.indexes("ex").find { |idx| idx.name == "include" }
            assert_equal ["number"], index.include
          end
        end

        def test_include_multiple_columns_index
          with_example_table do
            @connection.add_index "ex", %w{ id }, name: "include", include: [:number, :data]
            index = @connection.indexes("ex").find { |idx| idx.name == "include" }
            assert_equal ["number", "data"], index.include
          end
        end

        def test_include_keyword_column_name
          with_example_table("id integer, timestamp integer") do
            @connection.add_index "ex", :id, name: "include", include: [:timestamp]
            index = @connection.indexes("ex").find { |idx| idx.name == "include" }
            assert_equal ["timestamp"], index.include
          end
        end

        def test_include_escaped_quotes_column_name
          with_example_table(%{id integer, "I""like""quotes" integer}) do
            @connection.add_index "ex", :id, name: "include", include: [:"I\"like\"quotes"]
            index = @connection.indexes("ex").find { |idx| idx.name == "include" }
            assert_equal ["I\"like\"quotes"], index.include
          end
        end
      end

      def test_expression_index
        with_example_table do
          expr = "mod(id, 10), abs(number)"
          @connection.add_index "ex", expr, name: "expression"
          index = @connection.indexes("ex").find { |idx| idx.name == "expression" }
          assert_equal expr, index.columns
          assert_equal true, @connection.index_exists?("ex", expr, name: "expression")
        end
      end

      def test_index_with_opclass
        with_example_table do
          @connection.add_index "ex", "data", opclass: "varchar_pattern_ops"
          index = @connection.indexes("ex").find { |idx| idx.name == "index_ex_on_data" }
          assert_equal ["data"], index.columns

          @connection.remove_index "ex", "data"
          assert_not @connection.indexes("ex").find { |idx| idx.name == "index_ex_on_data" }
        end
      end

      def test_invalid_index
        with_example_table do
          @connection.exec_query("INSERT INTO ex (number) VALUES (1), (1)")
          error = assert_raises(ActiveRecord::RecordNotUnique) do
            @connection.add_index(:ex, :number, unique: true, algorithm: :concurrently, name: :invalid_index)
          end
          assert_match(/could not create unique index/, error.message)
          assert_equal @connection.pool, error.connection_pool

          assert @connection.index_exists?(:ex, :number, name: :invalid_index)
          assert_not @connection.index_exists?(:ex, :number, name: :invalid_index, valid: true)
          assert @connection.index_exists?(:ex, :number, name: :invalid_index, valid: false)
        end
      end

      def test_index_with_not_distinct_nulls
        skip("current adapter doesn't support nulls not distinct") unless supports_nulls_not_distinct?

        with_example_table do
          @connection.execute(<<~SQL)
            CREATE UNIQUE INDEX index_ex_on_data ON ex (data) NULLS NOT DISTINCT WHERE number > 0
          SQL

          index = @connection.indexes(:ex).first
          assert_equal true, index.unique
          assert_match("number", index.where)
        end
      end

      def test_index_keyword_column_name
        with_example_table("timestamp integer") do
          @connection.add_index "ex", :timestamp, name: "keyword"
          index = @connection.indexes("ex").find { |idx| idx.name == "keyword" }
          assert_equal ["timestamp"], index.columns
        end
      end

      def test_index_escaped_quotes_column_name
        with_example_table(%{"I""like""quotes" integer}) do
          @connection.add_index "ex", :"I\"like\"quotes", name: "quotes"
          index = @connection.indexes("ex").find { |idx| idx.name == "quotes" }
          assert_equal ["I\"like\"quotes"], index.columns
        end
      end

      def test_columns_for_distinct_zero_orders
        assert_equal "posts.id",
          @connection.columns_for_distinct("posts.id", [])
      end

      def test_columns_for_distinct_one_order
        assert_equal "posts.created_at AS alias_0, posts.id",
          @connection.columns_for_distinct("posts.id", ["posts.created_at desc"])
      end

      def test_columns_for_distinct_few_orders
        assert_equal "posts.created_at AS alias_0, posts.position AS alias_1, posts.id",
          @connection.columns_for_distinct("posts.id", ["posts.created_at desc", "posts.position asc"])
      end

      def test_columns_for_distinct_with_case
        assert_equal(
          "CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END AS alias_0, posts.id",
          @connection.columns_for_distinct("posts.id",
            ["CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END"])
        )
      end

      def test_columns_for_distinct_blank_not_nil_orders
        assert_equal "posts.created_at AS alias_0, posts.id",
          @connection.columns_for_distinct("posts.id", ["posts.created_at desc", "", "   "])
      end

      def test_columns_for_distinct_with_arel_order
        Arel::Table.engine = nil # should not rely on the global Arel::Table.engine

        order = Arel.sql("posts.created_at").desc
        assert_equal "posts.created_at AS alias_0, posts.id",
          @connection.columns_for_distinct("posts.id", [order])
      ensure
        Arel::Table.engine = ActiveRecord::Base
      end

      def test_columns_for_distinct_with_nulls
        assert_equal "posts.updater_id AS alias_0, posts.title", @connection.columns_for_distinct("posts.title", ["posts.updater_id desc nulls first"])
        assert_equal "posts.updater_id AS alias_0, posts.title", @connection.columns_for_distinct("posts.title", ["posts.updater_id desc nulls last"])
      end

      def test_columns_for_distinct_without_order_specifiers
        assert_equal "posts.updater_id AS alias_0, posts.title",
          @connection.columns_for_distinct("posts.title", ["posts.updater_id"])

        assert_equal "posts.updater_id AS alias_0, posts.title",
          @connection.columns_for_distinct("posts.title", ["posts.updater_id nulls last"])

        assert_equal "posts.updater_id AS alias_0, posts.title",
          @connection.columns_for_distinct("posts.title", ["posts.updater_id nulls first"])
      end

      def test_raise_error_when_cannot_translate_exception
        assert_raise TypeError do
          @connection.send(:log, nil) { @connection.execute(nil) }
        end
      end

      def test_translate_no_connection_exception_to_not_established
        pid = @connection.execute("SELECT pg_backend_pid()").to_a[0]["pg_backend_pid"]
        @connection.pool.checkout.execute("SELECT pg_terminate_backend(#{pid})")
        # If you run `@connection.execute` after the backend process has been terminated,
        # you will get the "server closed the connection unexpectedly" rather than "no connection to the server".
        # Because what we want to test here is an error that occurs during `send_query`,
        # which is called internally by `@connection.execute`, we will call it explicitly.
        # The `send_query` changes the internal `PG::Connection#status` to `CONNECTION_BAD`,
        # so any subsequent queries will get the "no connection to the server" error.
        # https://github.com/postgres/postgres/blob/REL_17_0/src/interfaces/libpq/fe-exec.c#L1686-L1691
        @connection.instance_variable_get(:@raw_connection).send_query("SELECT 1")

        assert_raise ActiveRecord::ConnectionNotEstablished do
          @connection.execute("SELECT 1")
        end
      end

      def test_reload_type_map_for_newly_defined_types
        @connection.create_enum "feeling", ["good", "bad"]

        # Runs only SELECT, no type map reloading.
        assert_queries_count(1, include_schema: true) do
          result = @connection.select_all "SELECT 'good'::feeling"
          assert_instance_of(PostgreSQLAdapter::OID::Enum,
                             result.column_types["feeling"])
        end
      ensure
        # Reloads type map.
        assert_queries_match(/from pg_type/i, include_schema: true) do
          @connection.drop_enum "feeling", if_exists: true
        end
        reset_connection
      end

      def test_only_reload_type_map_once_for_every_unrecognized_type
        reset_connection
        connection = ActiveRecord::Base.lease_connection
        connection.select_all "SELECT 1" # eagerly initialize the connection

        silence_warnings do
          assert_queries_count(2, include_schema: true) do
            connection.select_all "select 'pg_catalog.pg_class'::regclass"
          end
          assert_queries_count(1, include_schema: true) do
            connection.select_all "select 'pg_catalog.pg_class'::regclass"
          end
          assert_queries_count(2, include_schema: true) do
            connection.select_all "SELECT NULL::anyarray"
          end
        end
      ensure
        reset_connection
      end

      def test_only_warn_on_first_encounter_of_unrecognized_oid
        reset_connection
        connection = ActiveRecord::Base.lease_connection

        warning = capture(:stderr) {
          connection.select_all "select 'pg_catalog.pg_class'::regclass"
          connection.select_all "select 'pg_catalog.pg_class'::regclass"
          connection.select_all "select 'pg_catalog.pg_class'::regclass"
        }
        assert_match(/\Aunknown OID \d+: failed to recognize type of 'regclass'\. It will be treated as String\.\n\z/, warning)
      ensure
        reset_connection
      end

      def test_unparsed_defaults_are_at_least_set_when_saving
        with_example_table "id SERIAL PRIMARY KEY, number INTEGER NOT NULL DEFAULT (4 + 4) * 2 / 4" do
          number_klass = Class.new(ActiveRecord::Base) do
            self.table_name = "ex"
          end
          column = number_klass.columns_hash["number"]
          assert_nil column.default
          assert_nil column.default_function

          first_number = number_klass.new
          assert_nil first_number.number

          first_number.save!
          assert_equal 4, first_number.reload.number
        end
      end

      def test_only_check_for_insensitive_comparison_capability_once
        @connection.execute("CREATE DOMAIN example_type AS integer")

        with_example_table "id SERIAL PRIMARY KEY, number example_type" do
          number_klass = Class.new(ActiveRecord::Base) do
            self.table_name = "ex"
          end
          attribute = number_klass.arel_table[:number]
          assert_queries_count(include_schema: true) do
            @connection.case_insensitive_comparison(attribute, "foo")
          end
          assert_no_queries do
            @connection.case_insensitive_comparison(attribute, "foo")
          end
        end
      ensure
        @connection.execute("DROP DOMAIN example_type")
      end

      def test_extensions_omits_current_schema_name
        @connection.execute("DROP EXTENSION IF EXISTS hstore")
        @connection.execute("CREATE SCHEMA customschema")
        @connection.execute("CREATE EXTENSION hstore SCHEMA customschema")
        assert_includes @connection.extensions, "customschema.hstore"
      ensure
        @connection.execute("DROP SCHEMA IF EXISTS customschema CASCADE")
        @connection.execute("DROP EXTENSION IF EXISTS hstore")
      end

      def test_extensions_includes_non_current_schema_name
        @connection.execute("DROP EXTENSION IF EXISTS hstore")
        @connection.execute("CREATE EXTENSION hstore")
        assert_includes @connection.extensions, "hstore"
      ensure
        @connection.execute("DROP EXTENSION IF EXISTS hstore")
      end

      def test_ignores_warnings_when_behaviour_ignore
        with_db_warnings_action(:ignore) do
          # libpq prints a warning to stderr from C, so we need to stub
          # the whole file descriptors, not just Ruby's $stdout/$stderr.
          _out, err = capture_subprocess_io do
            result = @connection.execute("do $$ BEGIN RAISE WARNING 'foo'; END; $$")
            assert_equal [], result.to_a
          end
          assert_match(/WARNING:  foo/, err)
        end
      end

      def test_logs_warnings_when_behaviour_log
        with_db_warnings_action(:log) do
          sql_warning = "[ActiveRecord::SQLWarning] PostgreSQL SQL warning (01000)"

          assert_called_with(ActiveRecord::Base.logger, :warn, [sql_warning]) do
            @connection.execute("do $$ BEGIN RAISE WARNING 'PostgreSQL SQL warning'; END; $$")
          end
        end
      end

      def test_raises_warnings_when_behaviour_raise
        with_db_warnings_action(:raise) do
          error = assert_raises(ActiveRecord::SQLWarning) do
            @connection.execute("do $$ BEGIN RAISE WARNING 'PostgreSQL SQL warning'; END; $$")
          end
          assert_equal @connection.pool, error.connection_pool
        end
      end

      def test_reports_when_behaviour_report
        with_db_warnings_action(:report) do
          error_reporter = ActiveSupport::ErrorReporter.new
          subscriber = ActiveSupport::ErrorReporter::TestHelper::ErrorSubscriber.new

          Rails.define_singleton_method(:error) { error_reporter }
          Rails.error.subscribe(subscriber)

          @connection.execute("do $$ BEGIN RAISE WARNING 'PostgreSQL SQL warning'; END; $$")
          warning_event, * = subscriber.events.first

          assert_kind_of ActiveRecord::SQLWarning, warning_event
          assert_equal "PostgreSQL SQL warning", warning_event.message
        end
      end

      def test_warnings_behaviour_can_be_customized_with_a_proc
        warning_message = nil
        warning_level = nil
        warning_action = ->(warning) do
          warning_message = warning.message
          warning_level = warning.level
        end

        with_db_warnings_action(warning_action) do
          @connection.execute("do $$ BEGIN RAISE WARNING 'PostgreSQL SQL warning'; END; $$")

          assert_equal "PostgreSQL SQL warning", warning_message
          assert_equal "WARNING", warning_level
        end
      end

      def test_allowlist_of_warnings_to_ignore
        with_db_warnings_action(:raise, [/PostgreSQL SQL warning/]) do
          result = @connection.execute("do $$ BEGIN RAISE WARNING 'PostgreSQL SQL warning'; END; $$")

          assert_equal [], result.to_a
        end
      end

      def test_allowlist_of_warning_codes_to_ignore
        with_example_table do
          with_db_warnings_action(:raise, ["01000"]) do
            result = @connection.execute("do $$ BEGIN RAISE WARNING 'PostgreSQL SQL warning'; END; $$")
            assert_equal [], result.to_a
          end
        end
      end

      def test_does_not_raise_notice_level_warnings
        with_db_warnings_action(:raise, [/PostgreSQL SQL warning/]) do
          result = @connection.execute("DROP TABLE IF EXISTS non_existent_table")

          assert_equal [], result.to_a
        end
      end

      def test_date_decoding_enabled
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        connection = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(db_config.configuration_hash)

        with_postgresql_apdater_decode_dates do
          date = connection.select_value("select '2024-01-01'::date")
          assert_equal Date.new(2024, 01, 01), date
          assert_equal Date, date.class
        end
      end

      def test_date_decoding_disabled
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        connection = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(db_config.configuration_hash)

        date = connection.select_value("select '2024-01-01'::date")
        assert_equal "2024-01-01", date
        assert_equal String, date.class
      end

      def test_disable_extension_with_schema
        @connection.execute("CREATE SCHEMA custom_schema")
        @connection.execute("DROP EXTENSION IF EXISTS hstore")
        @connection.execute("CREATE EXTENSION hstore SCHEMA custom_schema")
        result = @connection.query("SELECT extname FROM pg_extension WHERE extnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'custom_schema')")
        assert_equal [["hstore"]], result.to_a

        @connection.disable_extension "custom_schema.hstore"
        result = @connection.query("SELECT extname FROM pg_extension WHERE extnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'custom_schema')")
        assert_equal [], result.to_a
      ensure
        @connection.execute("DROP EXTENSION IF EXISTS hstore")
        @connection.execute("DROP SCHEMA IF EXISTS custom_schema CASCADE")
      end

      def test_disable_extension_without_schema
        @connection.execute("DROP EXTENSION IF EXISTS hstore")
        @connection.execute("CREATE EXTENSION hstore")
        result = @connection.query("SELECT extname FROM pg_extension")
        assert_includes result.to_a, ["hstore"]

        @connection.disable_extension "hstore"
        result = @connection.query("SELECT extname FROM pg_extension")
        assert_not_includes result.to_a, ["hstore"]
      ensure
        @connection.execute("DROP EXTENSION IF EXISTS hstore")
      end

      private
        def with_postgresql_apdater_decode_dates
          PostgreSQLAdapter.decode_dates = true
          yield
        ensure
          PostgreSQLAdapter.decode_dates = false
        end

        def with_example_table(definition = "id serial primary key, number integer, data character varying(255)", &block)
          super(@connection, "ex", definition, &block)
        end

        def connection_without_insert_returning
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(db_config.configuration_hash.merge(insert_returning: false))
        end
    end
  end
end
