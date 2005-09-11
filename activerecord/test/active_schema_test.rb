require 'abstract_unit'

class ActiveSchemaTest < Test::Unit::TestCase
  def test_add_column_with_native_type_rejected
    assert_raises ActiveRecord::UnknownTypeError do
      add_column(:people, :varchar, :limit => 15)
    end
  end

  private
    def method_missing(method_symbol, *arguments)
      ActiveRecord::Base.connection.send(method_symbol, *arguments)
    end
end