require 'abstract_unit'
require 'active_support/core_ext/symbol'

class SymbolTests < ActiveSupport::TestCase

  class ExamplePredicateClass
    def so_true?
      true
    end

    def not_true?
      false
    end
  end

  def test_tilde_operator_in_case
    case ExamplePredicateClass.new
    when ~:not_true?
      clause = 'not-true'
    when ~:so_true?
      clause = 'so-true'
    else
      clause = 'else'
    end

    assert_equal 'so-true', clause
  end
end
