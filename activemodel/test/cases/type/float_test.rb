# frozen_string_literal: true

require 'cases/helper'

module ActiveModel
  module Type
    class FloatTest < ActiveModel::TestCase
      def test_type_cast_float
        type = Type::Float.new
        assert_equal 1.0, type.cast('1')
      end

      def test_type_cast_float_from_invalid_string
        type = Type::Float.new
        assert_nil type.cast('')
        assert_equal 1.0, type.cast('1ignore')
        assert_equal 0.0, type.cast('bad1')
        assert_equal 0.0, type.cast('bad')
      end

      def test_changing_float
        type = Type::Float.new

        assert type.changed?(0.0, 0, 'wibble')
        assert type.changed?(5.0, 0, 'wibble')
        assert_not type.changed?(5.0, 5.0, '5wibble')
        assert_not type.changed?(5.0, 5.0, '5')
        assert_not type.changed?(5.0, 5.0, '5.0')
        assert_not type.changed?(500.0, 500.0, '0.5E+4')
        assert_not type.changed?(nil, nil, nil)
      end
    end
  end
end
