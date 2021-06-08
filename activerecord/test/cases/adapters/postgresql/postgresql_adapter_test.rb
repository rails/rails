# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"
require "support/connection_helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::PostgreSQLTestCase
      self.use_transactional_tests = false
      include DdlHelper
      include ConnectionHelper

      def setup
        @connection = ActiveRecord::Base.connection
        @connection_handler = ActiveRecord::Base.connection_handler
      end

      def test_connection_error
        assert_raises ActiveRecord::ConnectionNotEstablished do
          ActiveRecord::Base.postgresql_connection(host: File::NULL)
        end
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

          def reset
            raise PG::ConnectionBad
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

        assert_raises ActiveRecord::ConnectionNotEstablished do
          @conn.reconnect!
        end
      end

      def test_bad_connection
        assert_raise ActiveRecord::NoDatabaseError do
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
          configuration = db_config.configuration_hash.merge(database: "should_not_exist-cinco-dog-db")
          connection = ActiveRecord::Base.postgresql_connection(configuration)
          connection.exec_query("SELECT 1")
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

        assert_raises(ActiveRecord::StatementInvalid) do
          @connection.serial_sequence("zomg", "id")
        end
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

      def test_reload_type_map_for_newly_defined_types
        @connection.execute "CREATE TYPE feeling AS ENUM ('good', 'bad')"
        result = @connection.select_all "SELECT 'good'::feeling"
        assert_instance_of(PostgreSQLAdapter::OID::Enum,
                           result.column_types["feeling"])
      ensure
        @connection.execute "DROP TYPE IF EXISTS feeling"
        reset_connection
      end

      def test_only_reload_type_map_once_for_every_unrecognized_type
        reset_connection
        connection = ActiveRecord::Base.connection

        silence_warnings do
          assert_queries 2, ignore_none: true do
            connection.select_all "select 'pg_catalog.pg_class'::regclass"
          end
          assert_queries 1, ignore_none: true do
            connection.select_all "select 'pg_catalog.pg_class'::regclass"
          end
          assert_queries 2, ignore_none: true do
            connection.select_all "SELECT NULL::anyarray"
          end
        end
      ensure
        reset_connection
      end

      def test_only_warn_on_first_encounter_of_unrecognized_oid
        reset_connection
        connection = ActiveRecord::Base.connection

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

      private
        def with_example_table(definition = "id serial primary key, number integer, data character varying(255)", &block)
          super(@connection, "ex", definition, &block)
        end

        def connection_without_insert_returning
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
          ActiveRecord::Base.postgresql_connection(db_config.configuration_hash.merge(insert_returning: false))
        end
    end
  end
end
