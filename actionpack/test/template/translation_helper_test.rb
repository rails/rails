require 'abstract_unit'

class TranslationHelperTest < ActiveSupport::TestCase
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
    assert_equal ["foo", "bar"], translate(["foo", "bar"])
  end

  def test_delegates_localize_to_i18n
    @time = Time.utc(2008, 7, 8, 12, 18, 38)
    I18n.expects(:localize).with(@time)
    localize @time
  end
  
  def test_scoping_by_partial
    I18n.expects(:translate).with("test.translation.helper", :raise => true).returns("helper")
    @view = ActionView::Base.new(ActionController::Base.view_paths, {})
    assert_equal "helper", @view.render(:file => "test/translation")
  end
end
