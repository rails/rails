require 'abstract_unit'

class TestCaseTest < ActionView::TestCase
  def test_should_have_current_url
    controller = TestController.new
    assert_nothing_raised(NoMethodError){ controller.url_for({:controller => "foo", :action => "index"}) }
  end
end
