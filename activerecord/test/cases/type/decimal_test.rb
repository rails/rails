# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module Type
    class DecimalTest < ActiveRecord::TestCase
      test "infinity raises range error" do
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "accounts"
          attribute :foo, :decimal
        end
        model = klass.new

        error = assert_raises(ActiveModel::RangeError) do
          model.foo = BigDecimal("Infinity")
          model.save
        end

        assert_equal "cannot be infinite", error.message
      end

      test "infinity with scale-less decimal raises range error" do
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "accounts"
          attribute :foo, Type::DecimalWithoutScale.new
        end
        model = klass.new

        error = assert_raises(ActiveModel::RangeError) do
          model.foo = BigDecimal("Infinity")
          model.save
        end

        assert_equal "cannot be infinite", error.message
      end

      test "negative infinity raises range error" do
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "accounts"
          attribute :foo, :decimal
        end
        model = klass.new

        error = assert_raises(ActiveModel::RangeError) do
          model.foo = BigDecimal("-Infinity")
          model.save
        end

        assert_equal "cannot be infinite", error.message
      end

      test "negative infinity with scale-less decimal raises range error" do
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "accounts"
          attribute :foo, Type::DecimalWithoutScale.new
        end
        model = klass.new

        error = assert_raises(ActiveModel::RangeError) do
          model.foo = BigDecimal("-Infinity")
          model.save
        end

        assert_equal "cannot be infinite", error.message
      end
    end
  end
end
