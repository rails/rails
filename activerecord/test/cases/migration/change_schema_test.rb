# frozen_string_literal: true

require 'cases/helper'

module ActiveRecord
  class Migration
    class ChangeSchemaTest < ActiveRecord::TestCase
      attr_reader :connection, :table_name

      def setup
        super
        @connection = ActiveRecord::Base.connection
        @table_name = :testings
      end

      teardown do
        connection.drop_table :testings rescue nil
        ActiveRecord::Base.primary_key_prefix_type = nil
        ActiveRecord::Base.clear_cache!
      end

      def test_create_table_without_id
        testing_table_with_only_foo_attribute do
          assert_equal connection.columns(:testings).size, 1
        end
      end

      def test_add_column_with_primary_key_attribute
        testing_table_with_only_foo_attribute do
          connection.add_column :testings, :id, :primary_key
          assert_equal connection.columns(:testings).size, 2
        end
      end

      def test_create_table_adds_id
        connection.create_table :testings do |t|
          t.column :foo, :string
        end

        assert_equal %w(id foo), connection.columns(:testings).map(&:name)
      end

      def test_create_table_with_not_null_column
        connection.create_table :testings do |t|
          t.column :foo, :string, null: false
        end

        assert_raises(ActiveRecord::NotNullViolation) do
          connection.execute 'insert into testings (foo) values (NULL)'
        end
      end

      def test_create_table_with_defaults
        # MySQL doesn't allow defaults on TEXT or BLOB columns.
        mysql = current_adapter?(:Mysql2Adapter)

        connection.create_table :testings do |t|
          t.column :one, :string, default: 'hello'
          t.column :two, :boolean, default: true
          t.column :three, :boolean, default: false
          t.column :four, :integer, default: 1
          t.column :five, :text, default: 'hello' unless mysql
        end

        columns = connection.columns(:testings)
        one = columns.detect { |c| c.name == 'one' }
        two = columns.detect { |c| c.name == 'two' }
        three = columns.detect { |c| c.name == 'three' }
        four = columns.detect { |c| c.name == 'four' }
        five = columns.detect { |c| c.name == 'five' } unless mysql

        assert_equal 'hello', one.default
        assert_equal true, connection.lookup_cast_type_from_column(two).deserialize(two.default)
        assert_equal false, connection.lookup_cast_type_from_column(three).deserialize(three.default)
        assert_equal '1', four.default
        assert_equal 'hello', five.default unless mysql
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_add_column_with_array
          connection.create_table :testings
          connection.add_column :testings, :foo, :string, array: true

          columns = connection.columns(:testings)
          array_column = columns.detect { |c| c.name == 'foo' }

          assert_predicate array_column, :array?
        end

        def test_create_table_with_array_column
          connection.create_table :testings do |t|
            t.string :foo, array: true
          end

          columns = connection.columns(:testings)
          array_column = columns.detect { |c| c.name == 'foo' }

          assert_predicate array_column, :array?
        end
      end

      def test_create_table_with_bigint
        connection.create_table :testings do |t|
          t.bigint :eight_int
        end
        columns = connection.columns(:testings)
        eight   = columns.detect { |c| c.name == 'eight_int'   }

        if current_adapter?(:OracleAdapter)
          assert_equal 'NUMBER(19)', eight.sql_type
        elsif current_adapter?(:SQLite3Adapter)
          assert_equal 'bigint', eight.sql_type
        else
          assert_equal :integer, eight.type
          assert_equal 8, eight.limit
        end
      ensure
        connection.drop_table :testings
      end

      def test_create_table_with_limits
        connection.create_table :testings do |t|
          t.column :foo, :string, limit: 255

          t.column :default_int, :integer

          t.column :one_int,    :integer, limit: 1
          t.column :four_int,   :integer, limit: 4
          t.column :eight_int,  :integer, limit: 8
        end

        columns = connection.columns(:testings)
        foo = columns.detect { |c| c.name == 'foo' }
        assert_equal 255, foo.limit

        default = columns.detect { |c| c.name == 'default_int' }
        one     = columns.detect { |c| c.name == 'one_int'     }
        four    = columns.detect { |c| c.name == 'four_int'    }
        eight   = columns.detect { |c| c.name == 'eight_int'   }

        if current_adapter?(:PostgreSQLAdapter)
          assert_equal 'integer', default.sql_type
          assert_equal 'smallint', one.sql_type
          assert_equal 'integer', four.sql_type
          assert_equal 'bigint', eight.sql_type
        elsif current_adapter?(:Mysql2Adapter)
          assert_match %r/\Aint/, default.sql_type
          assert_match %r/\Atinyint/, one.sql_type
          assert_match %r/\Aint/, four.sql_type
          assert_match %r/\Abigint/, eight.sql_type
        elsif current_adapter?(:OracleAdapter)
          assert_equal 'NUMBER(38)', default.sql_type
          assert_equal 'NUMBER(1)', one.sql_type
          assert_equal 'NUMBER(4)', four.sql_type
          assert_equal 'NUMBER(8)', eight.sql_type
        end
      end

      def test_create_table_with_primary_key_prefix_as_table_name_with_underscore
        ActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore

        connection.create_table :testings do |t|
          t.column :foo, :string
        end

        assert_equal %w(testing_id foo), connection.columns(:testings).map(&:name)
      end

      def test_create_table_with_primary_key_prefix_as_table_name
        ActiveRecord::Base.primary_key_prefix_type = :table_name

        connection.create_table :testings do |t|
          t.column :foo, :string
        end

        assert_equal %w(testingid foo), connection.columns(:testings).map(&:name)
      end

      def test_create_table_raises_when_redefining_primary_key_column
        error = assert_raise(ArgumentError) do
          connection.create_table :testings do |t|
            t.column :id, :string
          end
        end

        assert_equal "you can't redefine the primary key column 'id'. To define a custom primary key, pass { id: false } to create_table.", error.message
      end

      def test_create_table_raises_when_redefining_custom_primary_key_column
        error = assert_raise(ArgumentError) do
          connection.create_table :testings, primary_key: :testing_id do |t|
            t.column :testing_id, :string
          end
        end

        assert_equal "you can't redefine the primary key column 'testing_id'. To define a custom primary key, pass { id: false } to create_table.", error.message
      end

      def test_create_table_raises_when_defining_existing_column
        error = assert_raise(ArgumentError) do
          connection.create_table :testings do |t|
            t.column :testing_column, :string
            t.column :testing_column, :integer
          end
        end

        assert_equal "you can't define an already defined column 'testing_column'.", error.message
      end

      def test_create_table_with_timestamps_should_create_datetime_columns
        connection.create_table table_name do |t|
          t.timestamps
        end
        created_columns = connection.columns(table_name)

        created_at_column = created_columns.detect { |c| c.name == 'created_at' }
        updated_at_column = created_columns.detect { |c| c.name == 'updated_at' }

        assert_not created_at_column.null
        assert_not updated_at_column.null
      end

      def test_create_table_with_timestamps_should_create_datetime_columns_with_options
        connection.create_table table_name do |t|
          t.timestamps null: true
        end
        created_columns = connection.columns(table_name)

        created_at_column = created_columns.detect { |c| c.name == 'created_at' }
        updated_at_column = created_columns.detect { |c| c.name == 'updated_at' }

        assert created_at_column.null
        assert updated_at_column.null
      end

      def test_create_table_without_a_block
        connection.create_table table_name
      end

      # SQLite3 will not allow you to add a NOT NULL
      # column to a table without a default value.
      unless current_adapter?(:SQLite3Adapter)
        def test_add_column_not_null_without_default
          connection.create_table :testings do |t|
            t.column :foo, :string
          end
          connection.add_column :testings, :bar, :string, null: false

          assert_raise(ActiveRecord::NotNullViolation) do
            connection.execute "insert into testings (foo, bar) values ('hello', NULL)"
          end
        end
      end

      def test_add_column_not_null_with_default
        connection.create_table :testings do |t|
          t.column :foo, :string
        end

        quoted_id  = connection.quote_column_name('id')
        quoted_foo = connection.quote_column_name('foo')
        quoted_bar = connection.quote_column_name('bar')
        connection.execute("insert into testings (#{quoted_id}, #{quoted_foo}) values (1, 'hello')")
        assert_nothing_raised do
          connection.add_column :testings, :bar, :string, null: false, default: 'default'
        end

        assert_raises(ActiveRecord::NotNullViolation) do
          connection.execute("insert into testings (#{quoted_id}, #{quoted_foo}, #{quoted_bar}) values (2, 'hello', NULL)")
        end
      end

      def test_add_column_with_timestamp_type
        connection.create_table :testings do |t|
          t.column :foo, :timestamp
        end

        column = connection.columns(:testings).find { |c| c.name == 'foo' }

        assert_equal :datetime, column.type

        if current_adapter?(:PostgreSQLAdapter)
          assert_equal 'timestamp without time zone', column.sql_type
        elsif current_adapter?(:Mysql2Adapter)
          assert_equal 'timestamp', column.sql_type
        elsif current_adapter?(:OracleAdapter)
          assert_equal 'TIMESTAMP(6)', column.sql_type
        else
          assert_equal connection.type_to_sql('datetime'), column.sql_type
        end
      end

      def test_change_column_quotes_column_names
        connection.create_table :testings do |t|
          t.column :select, :string
        end

        connection.change_column :testings, :select, :string, limit: 10

        # Oracle needs primary key value from sequence
        if current_adapter?(:OracleAdapter)
          connection.execute "insert into testings (id, #{connection.quote_column_name('select')}) values (testings_seq.nextval, '7 chars')"
        else
          connection.execute "insert into testings (#{connection.quote_column_name('select')}) values ('7 chars')"
        end
      end

      def test_keeping_default_and_notnull_constraints_on_change
        connection.create_table :testings do |t|
          t.column :title, :string
        end
        person_klass = Class.new(ActiveRecord::Base)
        person_klass.table_name = 'testings'

        person_klass.connection.add_column 'testings', 'wealth', :integer, null: false, default: 99
        person_klass.reset_column_information
        assert_equal 99, person_klass.column_defaults['wealth']
        assert_equal false, person_klass.columns_hash['wealth'].null
        # Oracle needs primary key value from sequence
        if current_adapter?(:OracleAdapter)
          assert_nothing_raised { person_klass.connection.execute("insert into testings (id, title) values (testings_seq.nextval, 'tester')") }
        else
          assert_nothing_raised { person_klass.connection.execute("insert into testings (title) values ('tester')") }
        end

        # change column default to see that column doesn't lose its not null definition
        person_klass.connection.change_column_default 'testings', 'wealth', 100
        person_klass.reset_column_information
        assert_equal 100, person_klass.column_defaults['wealth']
        assert_equal false, person_klass.columns_hash['wealth'].null

        # rename column to see that column doesn't lose its not null and/or default definition
        person_klass.connection.rename_column 'testings', 'wealth', 'money'
        person_klass.reset_column_information
        assert_nil person_klass.columns_hash['wealth']
        assert_equal 100, person_klass.column_defaults['money']
        assert_equal false, person_klass.columns_hash['money'].null

        # change column
        person_klass.connection.change_column 'testings', 'money', :integer, null: false, default: 1000
        person_klass.reset_column_information
        assert_equal 1000, person_klass.column_defaults['money']
        assert_equal false, person_klass.columns_hash['money'].null

        # change column, make it nullable and clear default
        person_klass.connection.change_column 'testings', 'money', :integer, null: true, default: nil
        person_klass.reset_column_information
        assert_nil person_klass.columns_hash['money'].default
        assert_equal true, person_klass.columns_hash['money'].null

        # change_column_null, make it not nullable and set null values to a default value
        person_klass.connection.execute('UPDATE testings SET money = NULL')
        person_klass.connection.change_column_null 'testings', 'money', false, 2000
        person_klass.reset_column_information
        assert_nil person_klass.columns_hash['money'].default
        assert_equal false, person_klass.columns_hash['money'].null
        assert_equal 2000, connection.select_values('SELECT money FROM testings').first.to_i
      end

      def test_change_column_null
        testing_table_with_only_foo_attribute do
          notnull_migration = Class.new(ActiveRecord::Migration::Current) do
            def change
              change_column_null :testings, :foo, false
            end
          end
          notnull_migration.new.suppress_messages do
            notnull_migration.migrate(:up)
            assert_equal false, connection.columns(:testings).find { |c| c.name == 'foo' }.null
            notnull_migration.migrate(:down)
            assert connection.columns(:testings).find { |c| c.name == 'foo' }.null
          end
        end
      end

      def test_column_exists
        connection.create_table :testings do |t|
          t.column :foo, :string
        end

        assert connection.column_exists?(:testings, :foo)
        assert_not connection.column_exists?(:testings, :bar)
      end

      def test_column_exists_with_type
        connection.create_table :testings do |t|
          t.column :foo, :string
          t.column :bar, :decimal, precision: 8, scale: 2
        end

        assert connection.column_exists?(:testings, :foo, :string)
        assert_not connection.column_exists?(:testings, :foo, :integer)

        assert connection.column_exists?(:testings, :bar, :decimal)
        assert_not connection.column_exists?(:testings, :bar, :integer)
      end

      def test_column_exists_with_definition
        connection.create_table :testings do |t|
          t.column :foo, :string, limit: 100
          t.column :bar, :decimal, precision: 8, scale: 2
          t.column :taggable_id, :integer, null: false
          t.column :taggable_type, :string, default: 'Photo'
        end

        assert connection.column_exists?(:testings, :foo, :string, limit: 100)
        assert_not connection.column_exists?(:testings, :foo, :string, limit: nil)
        assert connection.column_exists?(:testings, :bar, :decimal, precision: 8, scale: 2)
        assert_not connection.column_exists?(:testings, :bar, :decimal, precision: nil, scale: nil)
        assert connection.column_exists?(:testings, :taggable_id, :integer, null: false)
        assert_not connection.column_exists?(:testings, :taggable_id, :integer, null: true)
        assert connection.column_exists?(:testings, :taggable_type, :string, default: 'Photo')
        assert_not connection.column_exists?(:testings, :taggable_type, :string, default: nil)
      end

      def test_column_exists_on_table_with_no_options_parameter_supplied
        connection.create_table :testings do |t|
          t.string :foo
        end
        connection.change_table :testings do |t|
          assert t.column_exists?(:foo)
          assert_not (t.column_exists?(:bar))
        end
      end

      def test_drop_table_if_exists
        connection.create_table(:testings)
        assert connection.table_exists?(:testings)
        connection.drop_table(:testings, if_exists: true)
        assert_not connection.table_exists?(:testings)
      end

      def test_drop_table_if_exists_nothing_raised
        assert_nothing_raised { connection.drop_table(:nonexistent, if_exists: true) }
      end

      private
        def testing_table_with_only_foo_attribute
          connection.create_table :testings, id: false do |t|
            t.column :foo, :string
          end

          yield
        end
    end

    if ActiveRecord::Base.connection.supports_foreign_keys?
      class ChangeSchemaWithDependentObjectsTest < ActiveRecord::TestCase
        self.use_transactional_tests = false

        setup do
          @connection = ActiveRecord::Base.connection
          @connection.create_table :trains
          @connection.create_table(:wagons) { |t| t.references :train }
          @connection.add_foreign_key :wagons, :trains
        end

        teardown do
          [:wagons, :trains].each do |table|
            @connection.drop_table table, if_exists: true
          end
        end

        def test_create_table_with_force_cascade_drops_dependent_objects
          if current_adapter?(:Mysql2Adapter)
            skip 'MySQL > 5.5 does not drop dependent objects with DROP TABLE CASCADE'
          elsif current_adapter?(:SQLite3Adapter)
            skip 'SQLite3 does not support DROP TABLE CASCADE syntax'
          end
          # can't re-create table referenced by foreign key
          assert_raises(ActiveRecord::StatementInvalid) do
            @connection.create_table :trains, force: true
          end

          # can recreate referenced table with force: :cascade
          @connection.create_table :trains, force: :cascade
          assert_equal [], @connection.foreign_keys(:wagons)
        end
      end
    end
  end
end
