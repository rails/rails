require 'abstract_unit'

class StringInquirerTest < ActiveSupport::TestCase
  def test_match
    assert ActiveSupport::StringInquirer.new("production").production?
  end

  def test_miss
    assert !ActiveSupport::StringInquirer.new("production").development?
  end

  def test_missing_question_mark
    assert_raise(NoMethodError) { ActiveSupport::StringInquirer.new("production").production }
  end

  def test_defined_match_after_call
    str = ActiveSupport::StringInquirer.new("production")
    str.production?
    assert str.respond_to?(:production?)
  end
end
