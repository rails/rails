require 'abstract_unit'

class ActiveRecordHelperI18nTest < Test::Unit::TestCase
  include ActionView::Helpers::ActiveRecordHelper
  
  attr_reader :request
  def setup
    @object = stub :errors => stub(:count => 1, :full_messages => ['full_messages'])
    stubs(:content_tag).returns 'content_tag'
    stubs(:locale)
    
    I18n.stubs(:t).with(:'header_message', :locale => 'en-US', :scope => [:active_record, :error], :count => 1, :object_name => '').returns "1 error prohibited this  from being saved"
    I18n.stubs(:t).with(:'message', :locale => 'en-US', :scope => [:active_record, :error]).returns 'There were problems with the following fields:'
  end

  def test_error_messages_for_given_a_locale_it_does_not_check_request_for_locale
    expects(:locale).never
    @object.errors.stubs(:count).returns 0
    error_messages_for(:object => @object, :locale => 'en-US')
  end
  
  def test_error_messages_for_given_no_locale_it_checks_request_for_locale
    expects(:locale).returns 'en-US'
    @object.errors.stubs(:count).returns 0
    error_messages_for(:object => @object)
  end
  
  def test_error_messages_for_given_a_header_message_option_it_does_not_translate_header_message
    I18n.expects(:translate).with(:'header_message', :locale => 'en-US', :scope => [:active_record, :error], :count => 1, :object_name => '').never
    error_messages_for(:object => @object, :header_message => 'header message', :locale => 'en-US')
  end

  def test_error_messages_for_given_no_header_message_option_it_translates_header_message
    I18n.expects(:t).with(:'header_message', :locale => 'en-US', :scope => [:active_record, :error], :count => 1, :object_name => '').returns 'header message'
    error_messages_for(:object => @object, :locale => 'en-US')
  end
  
  def test_error_messages_for_given_a_message_option_it_does_not_translate_message
    I18n.expects(:t).with(:'message', :locale => 'en-US', :scope => [:active_record, :error]).never
    error_messages_for(:object => @object, :message => 'message', :locale => 'en-US')
  end

  def test_error_messages_for_given_no_message_option_it_translates_message
    I18n.expects(:t).with(:'message', :locale => 'en-US', :scope => [:active_record, :error]).returns 'There were problems with the following fields:'
    error_messages_for(:object => @object, :locale => 'en-US')
  end
end