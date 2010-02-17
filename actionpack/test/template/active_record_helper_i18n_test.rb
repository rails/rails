require 'abstract_unit'

class ActiveRecordHelperI18nTest < Test::Unit::TestCase
  include ActionView::Helpers::ActiveRecordHelper

  attr_reader :request
  def setup
    @object = stub :errors => stub(:count => 1, :full_messages => ['full_messages'])
    @object_name = 'book'
    stubs(:content_tag).returns 'content_tag'

    I18n.stubs(:t).with(:'header', :locale => 'en', :scope => [:activerecord, :errors, :template], :count => 1, :model => '').returns "1 error prohibited this  from being saved"
    I18n.stubs(:t).with(:'body', :locale => 'en', :scope => [:activerecord, :errors, :template]).returns 'There were problems with the following fields:'
  end

  def test_error_messages_for_given_a_header_option_it_does_not_translate_header_message
    I18n.expects(:translate).with(:'header', :locale => 'en', :scope => [:activerecord, :errors, :template], :count => 1, :model => '').never
    error_messages_for(:object => @object, :header_message => 'header message', :locale => 'en')
  end

  def test_error_messages_for_given_no_header_option_it_translates_header_message
    I18n.expects(:t).with(:'header', :locale => 'en', :scope => [:activerecord, :errors, :template], :count => 1, :model => '').returns 'header message'
    I18n.expects(:t).with('', :default => '', :count => 1, :scope => [:activerecord, :models]).once.returns ''
    error_messages_for(:object => @object, :locale => 'en')
  end

  def test_error_messages_for_given_a_message_option_it_does_not_translate_message
    I18n.expects(:t).with(:'body', :locale => 'en', :scope => [:activerecord, :errors, :template]).never
    I18n.expects(:t).with('', :default => '', :count => 1, :scope => [:activerecord, :models]).once.returns ''
    error_messages_for(:object => @object, :message => 'message', :locale => 'en')
  end

  def test_error_messages_for_given_no_message_option_it_translates_message
    I18n.expects(:t).with(:'body', :locale => 'en', :scope => [:activerecord, :errors, :template]).returns 'There were problems with the following fields:'
    I18n.expects(:t).with('', :default => '', :count => 1, :scope => [:activerecord, :models]).once.returns ''
    error_messages_for(:object => @object, :locale => 'en')
  end

  def test_error_messages_for_given_object_name_it_translates_object_name
    I18n.expects(:t).with(:header, :locale => 'en', :scope => [:activerecord, :errors, :template], :count => 1, :model => @object_name).returns "1 error prohibited this #{@object_name} from being saved"
    I18n.expects(:t).with(@object_name, :default => @object_name, :count => 1, :scope => [:activerecord, :models]).once.returns @object_name
    error_messages_for(:object => @object, :locale => 'en', :object_name => @object_name)
  end

  def test_error_messages_for_given_object_name_with_underscore_it_translates_object_name
    I18n.expects(:t).with('bank_account', :default => 'bank account', :count => 1, :scope => [:activerecord, :models]).once.returns 'bank account'
    I18n.expects(:t).with(:header, :locale => 'en', :scope => [:activerecord, :errors, :template], :count => 1, :model => 'bank account').returns "1 error prohibited this bank account from being saved"
    error_messages_for(:object => @object, :locale => 'en', :object_name => 'bank_account')
  end
end

