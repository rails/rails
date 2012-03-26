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
      fail 'Reached not_true? clause'
    when ~:so_true?
      pass
    else
      fail 'Reached else clause'
    end
  end

end
