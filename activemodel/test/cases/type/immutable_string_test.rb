# frozen_string_literal: true

require 'cases/helper'

module ActiveModel
  module Type
    class ImmutableStringTest < ActiveModel::TestCase
      test 'cast strings are frozen' do
        s = 'foo'
        type = Type::ImmutableString.new
        assert_equal true, type.cast(s).frozen?
      end

      test 'immutable strings are not duped coming out' do
        s = 'foo'
        type = Type::ImmutableString.new
        assert_same s, type.cast(s)
        assert_same s, type.deserialize(s)
      end
    end
  end
end
