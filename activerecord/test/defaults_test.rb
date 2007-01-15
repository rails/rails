require 'abstract_unit'
require 'fixtures/default'
require 'fixtures/entrant'

class DefaultTest < Test::Unit::TestCase
  def test_nil_defaults_for_not_null_columns
    column_defaults =
      if current_adapter?(:MysqlAdapter)
        { 'id' => nil, 'name' => '',  'course_id' => nil }
      else
        { 'id' => nil, 'name' => nil, 'course_id' => nil }
      end

    column_defaults.each do |name, default|
      column = Entrant.columns_hash[name]
      assert !column.null, "#{name} column should be NOT NULL"
      assert_equal default, column.default, "#{name} column should be DEFAULT #{default.inspect}"
    end
  end

  if current_adapter?(:MysqlAdapter)
    # MySQL uses an implicit default 0 rather than NULL unless in strict mode.
    # We use an implicit NULL so schema.rb is compatible with other databases.
    def test_mysql_integer_not_null_defaults
      klass = Class.new(ActiveRecord::Base)
      klass.table_name = 'test_integer_not_null_default_zero'
      klass.connection.create_table klass.table_name do |t|
        t.column :zero, :integer, :null => false, :default => 0
        t.column :omit, :integer, :null => false
      end

      assert_equal 0, klass.columns_hash['zero'].default
      assert !klass.columns_hash['zero'].null
      assert_equal nil, klass.columns_hash['omit'].default
      assert !klass.columns_hash['omit'].null

      assert_raise(ActiveRecord::StatementInvalid) { klass.create! }

      assert_nothing_raised do
        instance = klass.create!(:omit => 1)
        assert_equal 0, instance.zero
        assert_equal 1, instance.omit
      end
    ensure
      klass.connection.drop_table(klass.table_name) rescue nil
    end
  end

  if current_adapter?(:PostgreSQLAdapter, :SQLServerAdapter, :FirebirdAdapter, :OpenBaseAdapter, :OracleAdapter)
    def test_default_integers
      default = Default.new
      assert_instance_of Fixnum, default.positive_integer
      assert_equal 1, default.positive_integer
      assert_instance_of Fixnum, default.negative_integer
      assert_equal -1, default.negative_integer
      assert_instance_of BigDecimal, default.decimal_number
      assert_equal BigDecimal.new("2.78"), default.decimal_number
    end
  end
end
