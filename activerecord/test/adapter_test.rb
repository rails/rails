require 'abstract_unit'

class AdapterTest < Test::Unit::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_tables
    if @connection.respond_to?(:tables)
      tables = @connection.tables
      assert tables.include?("accounts")
      assert tables.include?("authors")
      assert tables.include?("tasks")
      assert tables.include?("topics")
    else
      warn "#{@connection.class} does not respond to #tables"
    end
  end

  def test_indexes
    if @connection.respond_to?(:indexes)
      indexes = @connection.indexes("accounts")
      assert indexes.empty?

      @connection.add_index :accounts, :firm_id
      indexes = @connection.indexes("accounts")
      assert_equal "accounts", indexes.first.table
      assert_equal "accounts_firm_id_index", indexes.first.name
      assert !indexes.first.unique
      assert_equal ["firm_id"], indexes.first.columns
    else
      warn "#{@connection.class} does not respond to #indexes"
    end

  ensure
    @connection.remove_index :accounts, :firm_id rescue nil
  end
end
