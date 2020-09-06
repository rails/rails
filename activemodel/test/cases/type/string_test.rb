# frozen_string_literal: true

require 'cases/helper'

module ActiveModel
  module Type
    class StringTest < ActiveModel::TestCase
      test 'type casting' do
        type = Type::String.new
        assert_equal 't', type.cast(true)
        assert_equal 'f', type.cast(false)
        assert_equal '123', type.cast(123)
      end

      test 'type casting for database' do
        type = Type::String.new
        object, array, hash = Object.new, [true], { a: :b }
        assert_equal object, type.serialize(object)
        assert_equal array, type.serialize(array)
        assert_equal hash, type.serialize(hash)
      end

      test 'cast strings are mutable' do
        type = Type::String.new

        s = +'foo'
        assert_equal false, type.cast(s).frozen?
        assert_equal false, s.frozen?

        f = -'foo'
        assert_equal false, type.cast(f).frozen?
        assert_equal true, f.frozen?
      end

      test 'values are duped coming out' do
        type = Type::String.new

        s = 'foo'
        assert_not_same s, type.cast(s)
        assert_equal s, type.cast(s)
        assert_not_same s, type.deserialize(s)
        assert_equal s, type.deserialize(s)
      end
    end
  end
end
