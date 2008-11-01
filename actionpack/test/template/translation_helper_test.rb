require 'abstract_unit'

class TranslationHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper
  
  attr_reader :request
  uses_mocha 'translation_helper_test' do
    def setup
    end
    
    def test_delegates_to_i18n_setting_the_raise_option
      I18n.expects(:translate).with(:foo, :locale => 'en-US', :raise => true)
      translate :foo, :locale => 'en-US'
    end
    
    def test_returns_missing_translation_message_wrapped_into_span
      expected = '<span class="translation_missing">en-US, foo</span>'
      assert_equal expected, translate(:foo)
    end
  
    def test_delegates_localize_to_i18n
      @time = Time.utc(2008, 7, 8, 12, 18, 38)
      I18n.expects(:localize).with(@time)
      localize @time
    end
  end
end