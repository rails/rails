require 'abstract_unit'
require 'testing_sandbox'

class OutputSafetyHelperTest < ActionView::TestCase
  tests ActionView::Helpers::OutputSafetyHelper
  include TestingSandbox

  def setup
    @string = "hello"
  end

  test "raw returns the safe string" do
    result = raw(@string)
    assert_equal @string, result
    assert result.html_safe?
  end

  test "raw handles nil values correctly" do
    assert_equal "", raw(nil)
  end

  test "joining safe elements without a separator is safe" do
    array = 5.times.collect { "some string".html_safe }
    assert safe_join(array).html_safe?
  end

  test "Joining safe elements with a safe separator is safe" do
    array = 5.times.collect { "some string".html_safe }
    assert safe_join(array, "-".html_safe).html_safe?
  end

  test "Joining safe elements with an unsafe separator is unsafe" do
    array = 5.times.collect { "some string".html_safe }
    assert !safe_join(array, "-").html_safe?
  end

  test "Joining is unsafe if any element is unsafe even with a safe separator" do
    array = 5.times.collect { "some string".html_safe }
    array << "some string"
    assert !safe_join(array, "-".html_safe).html_safe?
  end

  test "Joining is unsafe if any element is unsafe and no separator is given" do
    array = 5.times.collect { "some string".html_safe }
    array << "some string"
    assert !safe_join(array).html_safe?
  end

  test "Joining is unsafe if any element is unsafe and the separator is unsafe" do
    array = 5.times.collect { "some string".html_safe }
    array << "some string"
    assert !safe_join(array, "-").html_safe?
  end

end