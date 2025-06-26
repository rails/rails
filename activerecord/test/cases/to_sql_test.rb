# frozen_string_literal: true

require "cases/helper"
require "models/car"

class ToSQLTest < ActiveRecord::TestCase
  fixtures :cars

  def test_relation_to_sql
    to_sql = assert_no_queries { Car.where(name: "honda").to_sql }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} WHERE #{quote_table_name('cars')}.#{quote_column_name('name')} = 'honda'", to_sql
  end

  def test_relation_to_sql_with_average
    to_sql = assert_no_queries { Car.all.to_sql.average(:id) }
    assert_equal "SELECT AVG(#{quote_table_name('cars')}.#{quote_column_name('id')}) FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_calculate
    to_sql = assert_no_queries { Car.all.to_sql.calculate(:average, :id) }
    assert_equal "SELECT AVG(#{quote_table_name('cars')}.#{quote_column_name('id')}) FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_count
    to_sql = assert_no_queries { Car.all.to_sql.count }
    assert_equal "SELECT COUNT(*) FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_count_and_argument
    to_sql = assert_no_queries { Car.all.to_sql.count(:id) }
    assert_equal "SELECT COUNT(#{quote_table_name('cars')}.#{quote_column_name('id')}) FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_exists
    to_sql = assert_no_queries { Car.all.to_sql.exists? }
    assert_equal "SELECT 1 AS one FROM #{quote_table_name('cars')} LIMIT 1", to_sql
  end

  def test_relation_to_sql_with_exists_with_argument
    to_sql = assert_no_queries { Car.all.to_sql.exists?(name: "JoshMobile") }
    assert_equal "SELECT 1 AS one FROM #{quote_table_name('cars')} WHERE #{quote_table_name('cars')}.#{quote_column_name('name')} = 'JoshMobile' LIMIT 1", to_sql
  end

  def test_relation_to_sql_with_find
    to_sql = assert_no_queries { Car.all.to_sql.find(1) }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} WHERE #{quote_table_name('cars')}.#{quote_column_name('id')} = 1 LIMIT 1", to_sql
  end

  def test_relation_to_sql_with_find_by
    to_sql = assert_no_queries { Car.all.to_sql.find_by(id: 1) }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} WHERE #{quote_table_name('cars')}.#{quote_column_name('id')} = 1 LIMIT 1", to_sql
  end

  def test_relation_to_sql_with_first
    to_sql = assert_no_queries { Car.all.to_sql.first }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} ORDER BY #{quote_table_name('cars')}.#{quote_column_name('id')} ASC LIMIT 1", to_sql
  end

  def test_relation_to_sql_with_first_with_argument
    to_sql = assert_no_queries { Car.all.to_sql.first(5) }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} ORDER BY #{quote_table_name('cars')}.#{quote_column_name('id')} ASC LIMIT 5", to_sql
  end

  def test_relation_to_sql_with_ids
    to_sql = assert_no_queries { Car.all.to_sql.ids }
    assert_equal "SELECT #{quote_table_name('cars')}.#{quote_column_name('id')} FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_last
    to_sql = assert_no_queries { Car.all.to_sql.last }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} ORDER BY #{quote_table_name('cars')}.#{quote_column_name('id')} DESC LIMIT 1", to_sql
  end

  def test_relation_to_sql_with_last_with_argument
    to_sql = assert_no_queries { Car.all.to_sql.last(5) }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} ORDER BY #{quote_table_name('cars')}.#{quote_column_name('id')} DESC LIMIT 5", to_sql
  end

  def test_relation_to_sql_with_maximum
    to_sql = assert_no_queries { Car.all.to_sql.maximum(:id) }
    assert_equal "SELECT MAX(#{quote_table_name('cars')}.#{quote_column_name('id')}) FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_minimum
    to_sql = assert_no_queries { Car.all.to_sql.minimum(:id) }
    assert_equal "SELECT MIN(#{quote_table_name('cars')}.#{quote_column_name('id')}) FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_pick
    to_sql = assert_no_queries { Car.all.to_sql.pick(:id) }
    assert_equal "SELECT #{quote_table_name('cars')}.#{quote_column_name('id')} FROM #{quote_table_name('cars')} LIMIT 1", to_sql
  end

  def test_relation_to_sql_with_pluck
    to_sql = assert_no_queries { Car.all.to_sql.pluck }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_pluck_with_args
    to_sql = assert_no_queries { Car.all.to_sql.pluck(:id, :name) }
    assert_equal "SELECT #{quote_table_name('cars')}.#{quote_column_name('id')}, #{quote_table_name('cars')}.#{quote_column_name('name')} FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_sum
    to_sql = assert_no_queries { Car.all.to_sql.sum(:id) }
    assert_equal "SELECT SUM(#{quote_table_name('cars')}.#{quote_column_name('id')}) FROM #{quote_table_name('cars')}", to_sql
  end

  def test_relation_to_sql_with_take
    to_sql = assert_no_queries { Car.all.to_sql.take }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} LIMIT 1", to_sql
  end

  def test_relation_to_sql_with_take_with_argument
    to_sql = assert_no_queries { Car.all.to_sql.take(5) }
    assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} LIMIT 5", to_sql
  end

  def test_relation_to_sql_with_binds
    to_sql = assert_no_queries { Car.all.where("id = ?", 1).to_sql }
    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} WHERE (id = '1')", to_sql
    else
      assert_equal "SELECT #{quote_table_name('cars')}.* FROM #{quote_table_name('cars')} WHERE (id = 1)", to_sql
    end
  end

  def test_relation_to_sql_with_binds_and_proxy_method
    to_sql = assert_no_queries { Car.all.where("id = ?", 1).to_sql.pluck(:id) }
    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      assert_equal "SELECT #{quote_table_name('cars')}.#{quote_column_name('id')} FROM #{quote_table_name('cars')} WHERE (id = '1')", to_sql
    else
      assert_equal "SELECT #{quote_table_name('cars')}.#{quote_column_name('id')} FROM #{quote_table_name('cars')} WHERE (id = 1)", to_sql
    end
  end
end
