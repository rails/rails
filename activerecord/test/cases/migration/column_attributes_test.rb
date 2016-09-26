require "cases/migration/helper"

module ActiveRecord
  class Migration
    class ColumnAttributesTest < ActiveRecord::TestCase
      include ActiveRecord::Migration::TestHelper

      self.use_transactional_tests = false

      def test_add_column_newline_default
        string = "foo\nbar"
        add_column "test_models", "command", :string, default: string
        TestModel.reset_column_information

        assert_equal string, TestModel.new.command
      end

      def test_add_remove_single_field_using_string_arguments
        assert_no_column TestModel, :last_name

        add_column "test_models", "last_name", :string
        assert_column TestModel, :last_name

        remove_column "test_models", "last_name"
        assert_no_column TestModel, :last_name
      end

      def test_add_remove_single_field_using_symbol_arguments
        assert_no_column TestModel, :last_name

        add_column :test_models, :last_name, :string
        assert_column TestModel, :last_name

        remove_column :test_models, :last_name
        assert_no_column TestModel, :last_name
      end

      def test_add_column_without_limit
        # TODO: limit: nil should work with all adapters.
        skip "MySQL wrongly enforces a limit of 255" if current_adapter?(:Mysql2Adapter)
        add_column :test_models, :description, :string, limit: nil
        TestModel.reset_column_information
        assert_nil TestModel.columns_hash["description"].limit
      end

      if current_adapter?(:Mysql2Adapter)
        def test_unabstracted_database_dependent_types
          add_column :test_models, :intelligence_quotient, :tinyint
          TestModel.reset_column_information
          assert_match(/tinyint/, TestModel.columns_hash["intelligence_quotient"].sql_type)
        end
      end

      unless current_adapter?(:SQLite3Adapter)
        # We specifically do a manual INSERT here, and then test only the SELECT
        # functionality. This allows us to more easily catch INSERT being broken,
        # but SELECT actually working fine.
        def test_native_decimal_insert_manual_vs_automatic
          correct_value = "0012345678901234567890.0123456789".to_d

          connection.add_column "test_models", "wealth", :decimal, precision: "30", scale: "10"

          # Do a manual insertion
          if current_adapter?(:OracleAdapter)
            connection.execute "insert into test_models (id, wealth) values (people_seq.nextval, 12345678901234567890.0123456789)"
          else
            connection.execute "insert into test_models (wealth) values (12345678901234567890.0123456789)"
          end

          # SELECT
          row = TestModel.first
          assert_kind_of BigDecimal, row.wealth

          # If this assert fails, that means the SELECT is broken!
          unless current_adapter?(:SQLite3Adapter)
            assert_equal correct_value, row.wealth
          end

          # Reset to old state
          TestModel.delete_all

          # Now use the Rails insertion
          TestModel.create wealth: BigDecimal.new("12345678901234567890.0123456789")

          # SELECT
          row = TestModel.first
          assert_kind_of BigDecimal, row.wealth

          # If these asserts fail, that means the INSERT (create function, or cast to SQL) is broken!
          assert_equal correct_value, row.wealth
        end
      end

      def test_add_column_with_precision_and_scale
        connection.add_column "test_models", "wealth", :decimal, precision: 9, scale: 7

        wealth_column = TestModel.columns_hash["wealth"]
        assert_equal 9, wealth_column.precision
        assert_equal 7, wealth_column.scale
      end

      if current_adapter?(:SQLite3Adapter)
        def test_change_column_preserve_other_column_precision_and_scale
          connection.add_column "test_models", "last_name", :string
          connection.add_column "test_models", "wealth", :decimal, precision: 9, scale: 7

          wealth_column = TestModel.columns_hash["wealth"]
          assert_equal 9, wealth_column.precision
          assert_equal 7, wealth_column.scale

          connection.change_column "test_models", "last_name", :string, null: false
          TestModel.reset_column_information

          wealth_column = TestModel.columns_hash["wealth"]
          assert_equal 9, wealth_column.precision
          assert_equal 7, wealth_column.scale
        end
      end

      unless current_adapter?(:SQLite3Adapter)
        def test_native_types
          add_column "test_models", "first_name", :string
          add_column "test_models", "last_name", :string
          add_column "test_models", "bio", :text
          add_column "test_models", "age", :integer
          add_column "test_models", "height", :float
          add_column "test_models", "wealth", :decimal, precision: "30", scale: "10"
          add_column "test_models", "birthday", :datetime
          add_column "test_models", "favorite_day", :date
          add_column "test_models", "moment_of_truth", :datetime
          add_column "test_models", "male", :boolean

          TestModel.create first_name: "bob", last_name: "bobsen",
            bio: "I was born ....", age: 18, height: 1.78,
            wealth: BigDecimal.new("12345678901234567890.0123456789"),
            birthday: 18.years.ago, favorite_day: 10.days.ago,
            moment_of_truth: "1782-10-10 21:40:18", male: true

          bob = TestModel.first
          assert_equal "bob", bob.first_name
          assert_equal "bobsen", bob.last_name
          assert_equal "I was born ....", bob.bio
          assert_equal 18, bob.age

          # Test for 30 significant digits (beyond the 16 of float), 10 of them
          # after the decimal place.

          assert_equal BigDecimal.new("0012345678901234567890.0123456789"), bob.wealth

          assert_equal true, bob.male?

          assert_equal String, bob.first_name.class
          assert_equal String, bob.last_name.class
          assert_equal String, bob.bio.class
          assert_kind_of Integer, bob.age
          assert_equal Time, bob.birthday.class
          assert_equal Date, bob.favorite_day.class
          assert_instance_of TrueClass, bob.male?
          assert_kind_of BigDecimal, bob.wealth
        end
      end

      if current_adapter?(:Mysql2Adapter, :PostgreSQLAdapter)
        def test_out_of_range_limit_should_raise
          assert_raise(ActiveRecordError) { add_column :test_models, :integer_too_big, :integer, limit: 10 }

          unless current_adapter?(:PostgreSQLAdapter)
            assert_raise(ActiveRecordError) { add_column :test_models, :text_too_big, :text, limit: 0xfffffffff }
          end
        end
      end
    end
  end
end
