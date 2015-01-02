require 'cases/helper'

if mysql_56?
  class DateTimeTest < ActiveRecord::TestCase
    self.use_transactional_fixtures = false

    class Foo < ActiveRecord::Base; end

    def test_default_datetime_precision
      ActiveRecord::Base.connection.create_table(:foos, force: true)
      ActiveRecord::Base.connection.add_column :foos, :created_at, :datetime
      ActiveRecord::Base.connection.add_column :foos, :updated_at, :datetime
      assert_nil activerecord_column_option('foos', 'created_at', 'precision')
    end

    def test_datetime_data_type_with_precision
      ActiveRecord::Base.connection.create_table(:foos, force: true)
      ActiveRecord::Base.connection.add_column :foos, :created_at, :datetime, precision: 1
      ActiveRecord::Base.connection.add_column :foos, :updated_at, :datetime, precision: 5
      assert_equal 1, activerecord_column_option('foos', 'created_at', 'precision')
      assert_equal 5, activerecord_column_option('foos', 'updated_at', 'precision')
    end

    def test_timestamps_helper_with_custom_precision
      ActiveRecord::Base.connection.create_table(:foos, force: true) do |t|
        t.timestamps null: true, precision: 4
      end
      assert_equal 4, activerecord_column_option('foos', 'created_at', 'precision')
      assert_equal 4, activerecord_column_option('foos', 'updated_at', 'precision')
    end

    def test_passing_precision_to_datetime_does_not_set_limit
      ActiveRecord::Base.connection.create_table(:foos, force: true) do |t|
        t.timestamps null: true, precision: 4
      end
      assert_nil activerecord_column_option('foos', 'created_at', 'limit')
      assert_nil activerecord_column_option('foos', 'updated_at', 'limit')
    end

    def test_invalid_datetime_precision_raises_error
      assert_raises ActiveRecord::ActiveRecordError do
        ActiveRecord::Base.connection.create_table(:foos, force: true) do |t|
          t.timestamps null: true, precision: 7
        end
      end
    end

    def test_mysql_agrees_with_activerecord_about_precision
      ActiveRecord::Base.connection.create_table(:foos, force: true) do |t|
        t.timestamps null: true, precision: 4
      end
      assert_equal 4, mysql_datetime_precision('foos', 'created_at')
      assert_equal 4, mysql_datetime_precision('foos', 'updated_at')
    end

    def test_formatting_datetime_according_to_precision
      ActiveRecord::Base.connection.create_table(:foos, force: true) do |t|
        t.datetime :created_at, precision: 0
        t.datetime :updated_at, precision: 4
      end
      date = ::Time.utc(2014, 8, 17, 12, 30, 0, 999999)
      Foo.create!(created_at: date, updated_at: date)
      assert foo = Foo.find_by(created_at: date)
      assert_equal date.to_s, foo.created_at.to_s
      assert_equal date.to_s, foo.updated_at.to_s
      assert_equal 000000, foo.created_at.usec
      assert_equal 999900, foo.updated_at.usec
    end

    private

    def mysql_datetime_precision(table_name, column_name)
      results = ActiveRecord::Base.connection.exec_query("SELECT column_name, datetime_precision FROM information_schema.columns WHERE table_name = '#{table_name}'")
      result = results.find do |result_hash|
        result_hash["column_name"] == column_name
      end
      result && result["datetime_precision"]
    end

    def activerecord_column_option(tablename, column_name, option)
      result = ActiveRecord::Base.connection.columns(tablename).find do |column|
        column.name == column_name
      end
      result && result.send(option)
    end
  end
end
