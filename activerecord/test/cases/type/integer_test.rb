require "cases/helper"
require "models/company"

module ActiveRecord
  module Type
    class IntegerTest < ActiveRecord::TestCase
      test "casting ActiveRecord models" do
        type = Type::Integer.new
        firm = Firm.create(name: "Apple")
        assert_nil type.cast(firm)
      end

      test "values which are out of range can be re-assigned" do
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "posts"
          attribute :foo, :integer
        end
        model = klass.new

        model.foo = 2147483648
        model.foo = 1

        assert_equal 1, model.foo
      end
    end
  end
end
