require 'abstract_unit'

class SymbolInquirerTest < ActiveSupport::TestCase
  def setup
    @symbol_inquirer = ActiveSupport::SymbolInquirer.new(:production)
  end

  def test_match
    assert @symbol_inquirer.production?
  end

  def test_miss
    assert_not @symbol_inquirer.development?
  end

  def test_missing_question_mark
    assert_raise(NoMethodError) { @symbol_inquirer.production }
  end

  def test_respond_to
    assert_respond_to @symbol_inquirer, :development?
  end
end
