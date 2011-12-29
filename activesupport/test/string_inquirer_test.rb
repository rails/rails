require 'abstract_unit'

class StringInquirerTest < Test::Unit::TestCase
  def test_match
    assert ActiveSupport::StringInquirer.new("production").production?
  end

  def test_miss
    assert !ActiveSupport::StringInquirer.new("production").development?
  end

  def test_match_string_method
    assert ActiveSupport::StringInquirer.new("all").all?
  end

  def test_miss_string_method
    assert !ActiveSupport::StringInquirer.new("production").all?
  end

  def test_string_comparison_match
    assert_equal "all", ActiveSupport::StringInquirer.new("all")
  end

  def test_string_comparison_match_coerce
    assert_equal ActiveSupport::StringInquirer.new("all"), "all"
  end

  def test_string_comparison_miss
    assert_not_equal "all", ActiveSupport::StringInquirer.new("none")
  end

  def test_missing_question_mark
    assert_raise(NoMethodError) { ActiveSupport::StringInquirer.new("production").production }
  end
end
