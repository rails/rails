require 'abstract_unit'

class TranslationHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper
  
  attr_reader :request
  def setup
  end
  
  def test_delegates_to_i18n_setting_the_raise_option
    I18n.expects(:translate).with(:foo, :locale => 'en', :raise => true).returns("")
    translate :foo, :locale => 'en'
  end
  
  def test_returns_missing_translation_message_wrapped_into_span
    expected = '<span class="translation_missing">en, foo</span>'
    assert_equal expected, translate(:foo)
  end
  
  def test_translation_of_an_array
    I18n.expects(:translate).with(["foo", "bar"], :raise => true).returns(["foo", "bar"])
    assert_equal "foobar", translate(["foo", "bar"])
  end

  def test_translation_of_an_array_with_html
    expected = '<a href="#">foo</a><a href="#">bar</a>'
    I18n.expects(:translate).with(["foo", "bar"], :raise => true).returns(['<a href="#">foo</a>', '<a href="#">bar</a>'])
    @view = ActionView::Base.new(ActionController::Base.view_paths, {})
    assert_equal expected, @view.render(:file => "test/array_translation")
  end

  def test_delegates_localize_to_i18n
    @time = Time.utc(2008, 7, 8, 12, 18, 38)
    I18n.expects(:localize).with(@time)
    localize @time
  end
  
  def test_scoping_by_partial
    expects(:template).returns(stub(:path_without_format_and_extension => "people/index"))
    I18n.expects(:translate).with("people.index.foo", :locale => 'en', :raise => true).returns("")
    translate ".foo", :locale => 'en'
  end

  def test_scoping_by_partial_of_an_array
    I18n.expects(:translate).with("test.scoped_array_translation.foo.bar", :raise => true).returns(["foo", "bar"])
    @view = ActionView::Base.new(ActionController::Base.view_paths, {})
    assert_equal "foobar", @view.render(:file => "test/scoped_array_translation")
  end
end
