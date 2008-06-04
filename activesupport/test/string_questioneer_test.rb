require 'abstract_unit'

class StringQuestioneerTest < Test::Unit::TestCase
  def test_match
    assert ActiveSupport::StringQuestioneer.new("production").production?
  end
  
  def test_miss
    assert !ActiveSupport::StringQuestioneer.new("production").development?
  end

  def test_missing_question_mark
    assert_raises(NoMethodError) { ActiveSupport::StringQuestioneer.new("production").production }
  end
end