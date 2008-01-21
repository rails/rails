require "cases/helper"
require 'models/course'

class FirebirdMigrationTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    # using Course connection for tests -- need a db that doesn't already have a BOOLEAN domain
    @connection = Course.connection
    @fireruby_connection = @connection.instance_variable_get(:@connection)
  end

  def teardown
    @connection.drop_table :foo rescue nil
    @connection.execute("DROP DOMAIN D_BOOLEAN") rescue nil
  end

  def test_create_table_with_custom_sequence_name
    assert_nothing_raised do
      @connection.create_table(:foo, :sequence => 'foo_custom_seq') do |f|
        f.column :bar, :string
      end
    end
    assert !sequence_exists?('foo_seq')
    assert sequence_exists?('foo_custom_seq')

    assert_nothing_raised { @connection.drop_table(:foo, :sequence => 'foo_custom_seq') }
    assert !sequence_exists?('foo_custom_seq')
  ensure
    FireRuby::Generator.new('foo_custom_seq', @fireruby_connection).drop rescue nil
  end

  def test_create_table_without_sequence
    assert_nothing_raised do
      @connection.create_table(:foo, :sequence => false) do |f|
        f.column :bar, :string
      end
    end
    assert !sequence_exists?('foo_seq')
    assert_nothing_raised { @connection.drop_table :foo }

    assert_nothing_raised do
      @connection.create_table(:foo, :id => false) do |f|
        f.column :bar, :string
      end
    end
    assert !sequence_exists?('foo_seq')
    assert_nothing_raised { @connection.drop_table :foo }
  end

  def test_create_table_with_boolean_column
    assert !boolean_domain_exists?
    assert_nothing_raised do
      @connection.create_table :foo do |f|
        f.column :bar, :string
        f.column :baz, :boolean
      end
    end
    assert boolean_domain_exists?
  end

  def test_add_boolean_column
    assert !boolean_domain_exists?
    @connection.create_table :foo do |f|
      f.column :bar, :string
    end

    assert_nothing_raised { @connection.add_column :foo, :baz, :boolean }
    assert boolean_domain_exists?
    assert_equal :boolean, @connection.columns(:foo).find { |c| c.name == "baz" }.type
  end

  def test_change_column_to_boolean
    assert !boolean_domain_exists?
    # Manually create table with a SMALLINT column, which can be changed to a BOOLEAN
    @connection.execute "CREATE TABLE foo (bar SMALLINT)"
    assert_equal :integer, @connection.columns(:foo).find { |c| c.name == "bar" }.type

    assert_nothing_raised { @connection.change_column :foo, :bar, :boolean }
    assert boolean_domain_exists?
    assert_equal :boolean, @connection.columns(:foo).find { |c| c.name == "bar" }.type
  end

  def test_rename_table_with_data_and_index
    @connection.create_table :foo do |f|
      f.column :baz, :string, :limit => 50
    end
    100.times { |i| @connection.execute "INSERT INTO foo VALUES (GEN_ID(foo_seq, 1), 'record #{i+1}')" }
    @connection.add_index :foo, :baz

    assert_nothing_raised { @connection.rename_table :foo, :bar }
    assert !@connection.tables.include?("foo")
    assert @connection.tables.include?("bar")
    assert_equal "index_bar_on_baz", @connection.indexes("bar").first.name
    assert_equal 100, FireRuby::Generator.new("bar_seq", @fireruby_connection).last
    assert_equal 100, @connection.select_one("SELECT COUNT(*) FROM bar")["count"]
  ensure
    @connection.drop_table :bar rescue nil
  end

  def test_renaming_table_with_fk_constraint_raises_error
    @connection.create_table :parent do |p|
      p.column :name, :string
    end
    @connection.create_table :child do |c|
      c.column :parent_id, :integer
    end
    @connection.execute "ALTER TABLE child ADD CONSTRAINT fk_child_parent FOREIGN KEY(parent_id) REFERENCES parent(id)"
    assert_raise(ActiveRecord::ActiveRecordError) { @connection.rename_table :child, :descendant }
  ensure
    @connection.drop_table :child rescue nil
    @connection.drop_table :descendant rescue nil
    @connection.drop_table :parent rescue nil
  end

  private
    def boolean_domain_exists?
      !@connection.select_one("SELECT 1 FROM rdb$fields WHERE rdb$field_name = 'D_BOOLEAN'").nil?
    end

    def sequence_exists?(sequence_name)
      FireRuby::Generator.exists?(sequence_name, @fireruby_connection)
    end
end
