# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/object/include"

class ObjectIncludeTest < ActiveSupport::TestCase
  module A
    def a
      "it works"
    end
  end

  class B
  end

  def test_include
    b = B.new
    
    refute b.respond_to?(:a)

    b.include(A)

    assert b.respond_to?(:a)
    assert_equal "it works", b.a

    refute B.new.respond_to?(:a)
  end
end