require 'abstract_unit'

class StringInquirerTest < Test::Unit::TestCase
  def test_match
    assert ActiveSupport::StringInquirer.new("production").production?
  end

  def test_miss
    assert !ActiveSupport::StringInquirer.new("production").development?
  end

  def test_missing_question_mark
    assert_raises(NoMethodError) { ActiveSupport::StringInquirer.new("production").production }
  end
end
