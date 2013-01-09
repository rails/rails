require 'cases/helper'
require 'models/developer'
require 'models/topic'

class TimestampTest < ActiveRecord::TestCase
  fixtures :topics

  def test_group_by_date
    keys = Topic.group("date_trunc('month', created_at)").count.keys
    assert_operator keys.length, :>, 0
    keys.each { |k| assert_kind_of Time, k }
  end

  def test_load_infinity_and_beyond
    unless current_adapter?(:PostgreSQLAdapter)
      return skip("only tested on postgresql")
    end

    d = Developer.find_by_sql("select 'infinity'::timestamp as updated_at")
    assert d.first.updated_at.infinite?, 'timestamp should be infinite'

    d = Developer.find_by_sql("select '-infinity'::timestamp as updated_at")
    time = d.first.updated_at
    assert time.infinite?, 'timestamp should be infinite'
    assert_operator time, :<, 0
  end

  def test_save_infinity_and_beyond
    unless current_adapter?(:PostgreSQLAdapter)
      return skip("only tested on postgresql")
    end

    d = Developer.create!(:name => 'aaron', :updated_at => 1.0 / 0.0)
    assert_equal(1.0 / 0.0, d.updated_at)

    d = Developer.create!(:name => 'aaron', :updated_at => -1.0 / 0.0)
    assert_equal(-1.0 / 0.0, d.updated_at)
  end

  def test_default_datetime_precision
    ActiveRecord::Base.connection.create_table(:foos)
    ActiveRecord::Base.connection.add_column :foos, :created_at, :datetime
    ActiveRecord::Base.connection.add_column :foos, :updated_at, :datetime
    assert_nil activerecord_column_option('foos', 'created_at', 'precision')
  end

  def test_timestamp_data_type_with_precision
    ActiveRecord::Base.connection.create_table(:foos)
    ActiveRecord::Base.connection.add_column :foos, :created_at, :datetime, :precision => 0
    ActiveRecord::Base.connection.add_column :foos, :updated_at, :datetime, :precision => 5
    assert_equal 0, activerecord_column_option('foos', 'created_at', 'precision')
    assert_equal 5, activerecord_column_option('foos', 'updated_at', 'precision')
  end

  def test_timestamps_helper_with_custom_precision
    ActiveRecord::Base.connection.create_table(:foos) do |t|
      t.timestamps :precision => 4
    end
    assert_equal 4, activerecord_column_option('foos', 'created_at', 'precision')
    assert_equal 4, activerecord_column_option('foos', 'updated_at', 'precision')
  end

  def test_passing_precision_to_timestamp_does_not_set_limit
    ActiveRecord::Base.connection.create_table(:foos) do |t|
      t.timestamps :precision => 4
    end
    assert_nil activerecord_column_option("foos", "created_at", "limit")
    assert_nil activerecord_column_option("foos", "updated_at", "limit")
  end

  def test_invalid_timestamp_precision_raises_error
    assert_raises ActiveRecord::ActiveRecordError do
      ActiveRecord::Base.connection.create_table(:foos) do |t|
        t.timestamps :precision => 7
      end
    end
  end

  def test_postgres_agrees_with_activerecord_about_precision
    ActiveRecord::Base.connection.create_table(:foos) do |t|
      t.timestamps :precision => 4
    end
    assert_equal '4', pg_datetime_precision('foos', 'created_at')
    assert_equal '4', pg_datetime_precision('foos', 'updated_at')
  end

  def test_bc_timestamp
    unless current_adapter?(:PostgreSQLAdapter)
      return skip("only tested on postgresql")
    end
    date = Date.new(0) - 1.second
    Developer.create!(:name => "aaron", :updated_at => date)
    assert_equal date, Developer.find_by_name("aaron").updated_at
  end

  private

    def pg_datetime_precision(table_name, column_name)
      results = ActiveRecord::Base.connection.execute("SELECT column_name, datetime_precision FROM information_schema.columns WHERE table_name ='#{table_name}'")
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
