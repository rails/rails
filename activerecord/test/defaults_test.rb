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

  if current_adapter?(:PostgreSQLAdapter, :SQLServerAdapter, :FirebirdAdapter, :OpenBaseAdapter)
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
