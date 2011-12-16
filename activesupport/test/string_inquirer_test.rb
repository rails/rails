require 'abstract_unit'

class StringInquirerTest < Test::Unit::TestCase
  def test_match_exactly
    assert ActiveSupport::StringInquirer.new("production").production?
  end

  def test_match_one
    assert ActiveSupport::StringInquirer.new("trick").trick_or_treat?
    assert ActiveSupport::StringInquirer.new("treat").trick_or_treat?
    assert ActiveSupport::StringInquirer.new("heinemeier").david_or_heinemeier_or_hansson?
  end

  def test_match_or
    assert ActiveSupport::StringInquirer.new("or").or_or_and?
    assert ActiveSupport::StringInquirer.new("or").and_or_or?
    assert ActiveSupport::StringInquirer.new("or").and_or_or_or_xor_or_not?
  end

  def test_miss
    assert !ActiveSupport::StringInquirer.new("production").development?
  end

  def test_missing_question_mark
    assert_raise(NoMethodError) { ActiveSupport::StringInquirer.new("production").production }
  end
end
