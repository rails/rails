# encoding: utf-8
require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::TestCase
      def setup
        @connection = ActiveRecord::Base.connection
        @connection.exec_query('drop table if exists ex')
        @connection.exec_query('create table ex(id serial primary key, number integer, data character varying(255))')
      end

      def test_primary_key
        assert_equal 'id', @connection.primary_key('ex')
      end

      def test_primary_key_works_tables_containing_capital_letters
        assert_equal 'id', @connection.primary_key('CamelCase')
      end

      def test_non_standard_primary_key
        @connection.exec_query('drop table if exists ex')
        @connection.exec_query('create table ex(data character varying(255) primary key)')
        assert_equal 'data', @connection.primary_key('ex')
      end

      def test_primary_key_returns_nil_for_no_pk
        @connection.exec_query('drop table if exists ex')
        @connection.exec_query('create table ex(id integer)')
        assert_nil @connection.primary_key('ex')
      end

      def test_primary_key_raises_error_if_table_not_found
        assert_raises(ActiveRecord::StatementInvalid) do
          @connection.primary_key('unobtainium')
        end
      end

      def test_insert_sql_with_proprietary_returning_clause
        id = @connection.insert_sql("insert into ex (number) values(5150)", nil, "number")
        assert_equal "5150", id
      end

      def test_insert_sql_with_quoted_schema_and_table_name
        id = @connection.insert_sql('insert into "public"."ex" (number) values(5150)')
        expect = @connection.query('select max(id) from ex').first.first
        assert_equal expect, id
      end

      def test_insert_sql_with_no_space_after_table_name
        id = @connection.insert_sql("insert into ex(number) values(5150)")
        expect = @connection.query('select max(id) from ex').first.first
        assert_equal expect, id
      end

      def test_insert_sql_with_returning_disabled
        connection = connection_without_insert_returning
        id = connection.insert_sql("insert into postgresql_partitioned_table_parent (number) VALUES (1)")
        expect = connection.query('select max(id) from postgresql_partitioned_table_parent').first.first
        assert_equal expect, id
      end

      def test_exec_insert_with_returning_disabled
        connection = connection_without_insert_returning
        result = connection.exec_insert("insert into postgresql_partitioned_table_parent (number) VALUES (1)", nil, [], 'id', 'postgresql_partitioned_table_parent_id_seq')
        expect = connection.query('select max(id) from postgresql_partitioned_table_parent').first.first
        assert_equal expect, result.rows.first.first
      end

      def test_exec_insert_with_returning_disabled_and_no_sequence_name_given
        connection = connection_without_insert_returning
        result = connection.exec_insert("insert into postgresql_partitioned_table_parent (number) VALUES (1)", nil, [], 'id')
        expect = connection.query('select max(id) from postgresql_partitioned_table_parent').first.first
        assert_equal expect, result.rows.first.first
      end

      def test_sql_for_insert_with_returning_disabled
        connection = connection_without_insert_returning
        result = connection.sql_for_insert('sql', nil, nil, nil, 'binds')
        assert_equal ['sql', 'binds'], result
      end

      def test_serial_sequence
        assert_equal 'public.accounts_id_seq',
          @connection.serial_sequence('accounts', 'id')

        assert_raises(ActiveRecord::StatementInvalid) do
          @connection.serial_sequence('zomg', 'id')
        end
      end

      def test_default_sequence_name
        assert_equal 'accounts_id_seq',
          @connection.default_sequence_name('accounts', 'id')

        assert_equal 'accounts_id_seq',
          @connection.default_sequence_name('accounts')
      end

      def test_default_sequence_name_bad_table
        assert_equal 'zomg_id_seq',
          @connection.default_sequence_name('zomg', 'id')

        assert_equal 'zomg_id_seq',
          @connection.default_sequence_name('zomg')
      end

      def test_pk_and_sequence_for
        pk, seq = @connection.pk_and_sequence_for('ex')
        assert_equal 'id', pk
        assert_equal @connection.default_sequence_name('ex', 'id'), seq
      end

      def test_pk_and_sequence_for_with_non_standard_primary_key
        @connection.exec_query('drop table if exists ex')
        @connection.exec_query('create table ex(code serial primary key)')
        pk, seq = @connection.pk_and_sequence_for('ex')
        assert_equal 'code', pk
        assert_equal @connection.default_sequence_name('ex', 'code'), seq
      end

      def test_pk_and_sequence_for_returns_nil_if_no_seq
        @connection.exec_query('drop table if exists ex')
        @connection.exec_query('create table ex(id integer primary key)')
        assert_nil @connection.pk_and_sequence_for('ex')
      end

      def test_pk_and_sequence_for_returns_nil_if_no_pk
        @connection.exec_query('drop table if exists ex')
        @connection.exec_query('create table ex(id integer)')
        assert_nil @connection.pk_and_sequence_for('ex')
      end

      def test_pk_and_sequence_for_returns_nil_if_table_not_found
        assert_nil @connection.pk_and_sequence_for('unobtainium')
      end

      def test_exec_insert_number
        insert(@connection, 'number' => 10)

        result = @connection.exec_query('SELECT number FROM ex WHERE number = 10')

        assert_equal 1, result.rows.length
        assert_equal "10", result.rows.last.last
      end

      def test_exec_insert_string
        str = 'いただきます！'
        insert(@connection, 'number' => 10, 'data' => str)

        result = @connection.exec_query('SELECT number, data FROM ex WHERE number = 10')

        value = result.rows.last.last

        assert_equal str, value
      end

      def test_table_alias_length
        assert_nothing_raised do
          @connection.table_alias_length
        end
      end

      def test_exec_no_binds
        result = @connection.exec_query('SELECT id, data FROM ex')
        assert_equal 0, result.rows.length
        assert_equal 2, result.columns.length
        assert_equal %w{ id data }, result.columns

        string = @connection.quote('foo')
        @connection.exec_query("INSERT INTO ex (id, data) VALUES (1, #{string})")
        result = @connection.exec_query('SELECT id, data FROM ex')
        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [['1', 'foo']], result.rows
      end

      def test_exec_with_binds
        string = @connection.quote('foo')
        @connection.exec_query("INSERT INTO ex (id, data) VALUES (1, #{string})")
        result = @connection.exec_query(
          'SELECT id, data FROM ex WHERE id = $1', nil, [[nil, 1]])

        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [['1', 'foo']], result.rows
      end

      def test_exec_typecasts_bind_vals
        string = @connection.quote('foo')
        @connection.exec_query("INSERT INTO ex (id, data) VALUES (1, #{string})")

        column = @connection.columns('ex').find { |col| col.name == 'id' }
        result = @connection.exec_query(
          'SELECT id, data FROM ex WHERE id = $1', nil, [[column, '1-fuu']])

        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [['1', 'foo']], result.rows
      end

      def test_substitute_at
        bind = @connection.substitute_at(nil, 0)
        assert_equal Arel.sql('$1'), bind

        bind = @connection.substitute_at(nil, 1)
        assert_equal Arel.sql('$2'), bind
      end

      def test_partial_index
        @connection.add_index 'ex', %w{ id number }, :name => 'partial', :where => "number > 100"
        index = @connection.indexes('ex').find { |idx| idx.name == 'partial' }
        assert_equal "(number > 100)", index.where
      end

      def test_distinct_zero_orders
        assert_equal "DISTINCT posts.id",
          @connection.distinct("posts.id", [])
      end

      def test_distinct_one_order
        assert_equal "DISTINCT posts.id, posts.created_at AS alias_0",
          @connection.distinct("posts.id", ["posts.created_at desc"])
      end

      def test_distinct_few_orders
        assert_equal "DISTINCT posts.id, posts.created_at AS alias_0, posts.position AS alias_1",
          @connection.distinct("posts.id", ["posts.created_at desc", "posts.position asc"])
      end

      def test_distinct_blank_not_nil_orders
        assert_equal "DISTINCT posts.id, posts.created_at AS alias_0",
          @connection.distinct("posts.id", ["posts.created_at desc", "", "   "])
      end

      def test_distinct_with_arel_order
        order = Object.new
        def order.to_sql
          "posts.created_at desc"
        end
        assert_equal "DISTINCT posts.id, posts.created_at AS alias_0",
          @connection.distinct("posts.id", [order])
      end

      def test_distinct_with_nulls
        assert_equal "DISTINCT posts.title, posts.updater_id AS alias_0", @connection.distinct("posts.title", ["posts.updater_id desc nulls first"])
        assert_equal "DISTINCT posts.title, posts.updater_id AS alias_0", @connection.distinct("posts.title", ["posts.updater_id desc nulls last"])
      end

      private
      def insert(ctx, data)
        binds   = data.map { |name, value|
          [ctx.columns('ex').find { |x| x.name == name }, value]
        }
        columns = binds.map(&:first).map(&:name)

        bind_subs = columns.length.times.map { |x| "$#{x + 1}" }

        sql = "INSERT INTO ex (#{columns.join(", ")})
               VALUES (#{bind_subs.join(', ')})"

        ctx.exec_insert(sql, 'SQL', binds)
      end

      def connection_without_insert_returning
        ActiveRecord::Base.postgresql_connection(ActiveRecord::Base.configurations['arunit'].merge(:insert_returning => false))
      end
    end
  end
end
