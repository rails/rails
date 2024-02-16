# frozen_string_literal: true

require_relative "../../abstract_unit"
require "bigdecimal"
require "active_support/core_ext/object/duplicable"
require "active_support/core_ext/numeric/time"

class DuplicableTest < ActiveSupport::TestCase
  OBJECTS = [
     method(:puts), method(:puts).unbind, Class.new.include(Singleton).instance,
    "1", "symbol_from_string".to_sym, Object.new, /foo/, [], {}, Time.now, Class.new,
    Module.new, BigDecimal("4.56"), nil, false, true, 1, 2.3, Complex(1), Rational(1),
  ]

  OBJECTS.each do |v|
    test "#{v.class}#duplicable? matches #{v.class}#dup behavior" do
      duplicable = begin
        v.dup
        true
      rescue TypeError
        false
      end

      if duplicable
        assert_predicate v, :duplicable?
      else
        assert_not_predicate v, :duplicable?
      end
    end
  end
end
