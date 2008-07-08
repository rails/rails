require 'abstract_unit'

class TranslationHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper
  
  attr_reader :request
  uses_mocha 'translation_helper_test' do
    def setup
    end
    
    def test_delegates_to_i18n_setting_the_raise_option
      I18n.expects(:translate).with(:foo, 'en-US', :raise => true)
      translate :foo, 'en-US'
    end
    
    def test_returns_missing_translation_message_wrapped_into_span
      expected = '<span class="translation_missing">en-US, foo</span>'
      assert_equal expected, translate(:foo)
    end

    # def test_error_messages_for_given_a_header_message_option_it_does_not_translate_header_message
    #   I18n.expects(:translate).with(:'header_message', :locale => 'en-US', :scope => [:active_record, :error], :count => 1, :object_name => '').never
    #   error_messages_for(:object => @object, :header_message => 'header message', :locale => 'en-US')
    # end
    # 
    # def test_error_messages_for_given_no_header_message_option_it_translates_header_message
    #   I18n.expects(:t).with(:'header_message', :locale => 'en-US', :scope => [:active_record, :error], :count => 1, :object_name => '').returns 'header message'
    #   error_messages_for(:object => @object, :locale => 'en-US')
    # end
    # 
    # def test_error_messages_for_given_a_message_option_it_does_not_translate_message
    #   I18n.expects(:t).with(:'message', :locale => 'en-US', :scope => [:active_record, :error]).never
    #   error_messages_for(:object => @object, :message => 'message', :locale => 'en-US')
    # end
    # 
    # def test_error_messages_for_given_no_message_option_it_translates_message
    #   I18n.expects(:t).with(:'message', :locale => 'en-US', :scope => [:active_record, :error]).returns 'There were problems with the following fields:'
    #   error_messages_for(:object => @object, :locale => 'en-US')
    # end
  end
  
  def test_delegates_localize_to_i18n
    @time = Time.utc(2008, 7, 8, 12, 18, 38)
    assert_equal "Tue, 08 Jul 2008 12:18:38 +0100", localize(@time)
    assert_equal "08 Jul 12:18", localize(@time, :format => :short)
  end
end