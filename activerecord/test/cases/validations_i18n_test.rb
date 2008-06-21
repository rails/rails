require "cases/helper"
require 'models/topic'
require 'models/reply'

class ActiveRecordValidationsI18nTests < Test::Unit::TestCase
  def setup
    reset_callbacks Topic
    @topic = Topic.new
    I18n.backend.store_translations('en-US', :active_record => {:error_messages => {:custom => nil}})
  end
  
  def teardown
    reset_callbacks Topic
    load 'active_record/lang/en-US.rb'
  end
  
  def unique_topic
    @unique ||= Topic.create :title => 'unique!'
  end
  
  def replied_topic
    @replied_topic ||= begin
      topic = Topic.create(:title => "topic")
      topic.replies << Reply.new
      topic
    end
  end
  
  def reset_callbacks(*models)
    models.each do |model|
      model.instance_variable_set("@validate_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
      model.instance_variable_set("@validate_on_create_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
      model.instance_variable_set("@validate_on_update_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
    end
  end
  
  # ActiveRecord::Errors
  
  def test_errors_generate_message_translates_custom_model_attribute_key
    global_scope = [:active_record, :error_messages]
    custom_scope = global_scope + [:custom, 'topic', :title]
    
    I18n.expects(:translate).with(:invalid, :scope => custom_scope).returns 'translation'
    I18n.expects(:translate).with(:invalid, :scope => global_scope).never
    
    @topic.errors.generate_message :title, :invalid
  end
  
  def test_errors_generate_message_given_a_custom_message_translates_custom_model_attribute_key_with_custom_message_as_default
    custom_scope = [:active_record, :error_messages, :custom, 'topic', :title]
    
    I18n.expects(:translate).with(:invalid, :scope => custom_scope, :default => 'default from class def').returns 'translation'
    @topic.errors.generate_message :title, :invalid, :default => 'default from class def'
  end
  
  def test_errors_generate_message_given_no_custom_message_falls_back_to_global_default_key_translation
    global_scope = [:active_record, :error_messages]
    custom_scope = global_scope + [:custom, 'topic', :title]

    I18n.stubs(:translate).with(:invalid, :scope => custom_scope).returns nil
    I18n.expects(:translate).with(:invalid, :scope => global_scope)
    @topic.errors.generate_message :title, :invalid
  end
  
  def test_errors_add_given_no_message_it_translates_invalid
    I18n.expects(:translate).with(:"active_record.error_messages.invalid")
    @topic.errors.add :title
  end
  
  def test_errors_add_on_empty_generates_message
    @topic.errors.expects(:generate_message).with(:title, :empty, {:default => nil})
    @topic.errors.add_on_empty :title
  end
  
  def test_errors_add_on_empty_generates_message_with_custom_default_message
    @topic.errors.expects(:generate_message).with(:title, :empty, {:default => 'custom'})
    @topic.errors.add_on_empty :title, 'custom'
  end
  
  def test_errors_add_on_blank_generates_message
    @topic.errors.expects(:generate_message).with(:title, :blank, {:default => nil})
    @topic.errors.add_on_blank :title
  end
  
  def test_errors_add_on_blank_generates_message_with_custom_default_message
    @topic.errors.expects(:generate_message).with(:title, :blank, {:default => 'custom'})
    @topic.errors.add_on_blank :title, 'custom'
  end
  
  def test_errors_full_messages_translates_human_attribute_name_for_model_attributes
    @topic.errors.instance_variable_set :@errors, { 'title' => 'empty' }
    I18n.expects(:translate).with(:"active_record.human_attribute_names.topic.title", 'en-US').returns('Title')
    @topic.errors.full_messages :locale => 'en-US'
  end
  
  
  # ActiveRecord::Validations
  
  # validates_confirmation_of
  
  def test_validates_confirmation_of_generates_message
    Topic.validates_confirmation_of :title
    @topic.title_confirmation = 'foo'
    @topic.errors.expects(:generate_message).with(:title, :confirmation, {:default => nil})
    @topic.valid?
  end
  
  def test_validates_confirmation_of_generates_message_with_custom_default_message
    Topic.validates_confirmation_of :title, :message => 'custom'
    @topic.title_confirmation = 'foo'
    @topic.errors.expects(:generate_message).with(:title, :confirmation, {:default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_confirmation_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:confirmation => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:confirmation => 'global message'}}

    Topic.validates_confirmation_of :title
    @topic.title_confirmation = 'foo'
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_confirmation_of_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:confirmation => 'global message'}}

    Topic.validates_confirmation_of :title
    @topic.title_confirmation = 'foo'
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_acceptance_of

  def test_validates_acceptance_of_generates_message
    Topic.validates_acceptance_of :title, :allow_nil => false
    @topic.errors.expects(:generate_message).with(:title, :accepted, {:default => nil})
    @topic.valid?
  end

  def test_validates_acceptance_of_generates_message_with_custom_default_message
    Topic.validates_acceptance_of :title, :message => 'custom', :allow_nil => false
    @topic.errors.expects(:generate_message).with(:title, :accepted, {:default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_acceptance_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:accepted => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:accepted => 'global message'}}

    Topic.validates_acceptance_of :title, :allow_nil => false
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_acceptance_of_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:accepted => 'global message'}}

    Topic.validates_acceptance_of :title, :allow_nil => false
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_presence_of

  def test_validates_presence_of_generates_message
    Topic.validates_presence_of :title
    @topic.errors.expects(:generate_message).with(:title, :blank, {:default => nil})
    @topic.valid?
  end
  
  def test_validates_presence_of_generates_message_with_custom_default_message
    Topic.validates_presence_of :title, :message => 'custom'
    @topic.errors.expects(:generate_message).with(:title, :blank, {:default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_presence_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:blank => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:blank => 'global message'}}

    Topic.validates_presence_of :title
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_presence_of_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:blank => 'global message'}}

    Topic.validates_presence_of :title
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_length_of :within

  def test_validates_length_of_within_generates_message
    Topic.validates_length_of :title, :within => 3..5
    @topic.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => nil})
    @topic.valid?
  end
  
  def test_validates_length_of_within_generates_message_with_custom_default_message
    Topic.validates_length_of :title, :within => 3..5, :too_short => 'custom'
    @topic.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_length_of_within_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:too_short => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:too_short => 'global message'}}

    Topic.validates_length_of :title, :within => 3..5
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_length_of_within_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:too_short => 'global message'}}

    Topic.validates_length_of :title, :within => 3..5
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_length_of :is
  
  def test_validates_length_of_is_generates_message
    Topic.validates_length_of :title, :is => 5
    @topic.errors.expects(:generate_message).with(:title, :wrong_length, {:count => 5, :default => nil})
    @topic.valid?
  end
  
  def test_validates_length_of_is_generates_message_with_custom_default_message
    Topic.validates_length_of :title, :is => 5, :message => 'custom'
    @topic.errors.expects(:generate_message).with(:title, :wrong_length, {:count => 5, :default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_length_of_within_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:wrong_length => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:wrong_length => 'global message'}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_length_of_within_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:wrong_length => 'global message'}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_uniqueness_of
  
  def test_validates_uniqueness_of_generates_message
    Topic.validates_uniqueness_of :title
    @topic.title = unique_topic.title
    @topic.errors.expects(:generate_message).with(:title, :taken, {:default => nil})
    @topic.valid?
  end
  
  def test_validates_uniqueness_of_generates_message_with_custom_default_message
    Topic.validates_uniqueness_of :title, :message => 'custom'
    @topic.title = unique_topic.title
    @topic.errors.expects(:generate_message).with(:title, :taken, {:default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_length_of_within_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:wrong_length => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:wrong_length => 'global message'}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_length_of_within_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:wrong_length => 'global message'}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_format_of
  
  def test_validates_format_of_generates_message
    Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @topic.title = '72x'
    @topic.errors.expects(:generate_message).with(:title, :invalid, {:value => '72x', :default => nil})
    @topic.valid?
  end
  
  def test_validates_format_of_generates_message_with_custom_default_message
    Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/, :message => 'custom'
    @topic.title = '72x'
    @topic.errors.expects(:generate_message).with(:title, :invalid, {:value => '72x', :default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_format_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:invalid => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:invalid => 'global message'}}

    Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_format_of_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:invalid => 'global message'}}

    Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_inclusion_of
  
  def test_validates_inclusion_of_generates_message
    Topic.validates_inclusion_of :title, :in => %w(a b c)
    @topic.title = 'z'
    @topic.errors.expects(:generate_message).with(:title, :inclusion, {:value => 'z', :default => nil})
    @topic.valid?
  end
  
  def test_validates_inclusion_of_generates_message_with_custom_default_message
    Topic.validates_inclusion_of :title, :in => %w(a b c), :message => 'custom'
    @topic.title = 'z'
    @topic.errors.expects(:generate_message).with(:title, :inclusion, {:value => 'z', :default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_inclusion_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:inclusion => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:inclusion => 'global message'}}

    Topic.validates_inclusion_of :title, :in => %w(a b c)
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_inclusion_of_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:inclusion => 'global message'}}

    Topic.validates_inclusion_of :title, :in => %w(a b c)
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_exclusion_of
  
  def test_validates_exclusion_of_generates_message
    Topic.validates_exclusion_of :title, :in => %w(a b c)
    @topic.title = 'a'
    @topic.errors.expects(:generate_message).with(:title, :exclusion, {:value => 'a', :default => nil})
    @topic.valid?
  end
  
  def test_validates_exclusion_of_generates_message_with_custom_default_message
    Topic.validates_exclusion_of :title, :in => %w(a b c), :message => 'custom'
    @topic.title = 'a'
    @topic.errors.expects(:generate_message).with(:title, :exclusion, {:value => 'a', :default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_exclusion_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:exclusion => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:exclusion => 'global message'}}

    Topic.validates_exclusion_of :title, :in => %w(a b c)
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_exclusion_of_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:exclusion => 'global message'}}

    Topic.validates_exclusion_of :title, :in => %w(a b c)
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_numericality_of :only_integer
  
  def test_validates_numericality_of_only_integer_generates_message
    Topic.validates_numericality_of :title, :only_integer => true
    @topic.title = 'a'
    @topic.errors.expects(:generate_message).with(:title, :not_a_number, {:value => 'a', :default => nil})
    @topic.valid?
  end
  
  def test_validates_numericality_of_only_integer_generates_message_with_custom_default_message
    Topic.validates_numericality_of :title, :only_integer => true, :message => 'custom'
    @topic.title = 'a'
    @topic.errors.expects(:generate_message).with(:title, :not_a_number, {:value => 'a', :default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_numericality_of_only_integer_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:not_a_number => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:not_a_number => 'global message'}}

    Topic.validates_numericality_of :title, :only_integer => true
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_numericality_of_only_integer_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:not_a_number => 'global message'}}

    Topic.validates_numericality_of :title, :only_integer => true
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_numericality_of :odd
  
  def test_validates_numericality_of_odd_generates_message
    Topic.validates_numericality_of :title, :only_integer => true, :odd => true
    @topic.title = 0
    @topic.errors.expects(:generate_message).with(:title, :odd, {:value => 0, :default => nil})
    @topic.valid?
  end
  
  def test_validates_numericality_of_odd_generates_message_with_custom_default_message
    Topic.validates_numericality_of :title, :only_integer => true, :odd => true, :message => 'custom'
    @topic.title = 0
    @topic.errors.expects(:generate_message).with(:title, :odd, {:value => 0, :default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_numericality_of_odd_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:odd => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:odd => 'global message'}}

    Topic.validates_numericality_of :title, :only_integer => true, :odd => true
    @topic.title = 0
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_numericality_of_odd_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:odd => 'global message'}}

    Topic.validates_numericality_of :title, :only_integer => true, :odd => true
    @topic.title = 0
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_numericality_of :less_than
  
  def test_validates_numericality_of_less_than_generates_message
    Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @topic.title = 1
    @topic.errors.expects(:generate_message).with(:title, :less_than, {:value => 1, :count => 0, :default => nil})
    @topic.valid?
  end
  
  def test_validates_numericality_of_odd_generates_message_with_custom_default_message
    Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0, :message => 'custom'
    @topic.title = 1
    @topic.errors.expects(:generate_message).with(:title, :less_than, {:value => 1, :count => 0, :default => 'custom'})
    @topic.valid?
  end
  
  def test_validates_numericality_of_less_than_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:title => {:less_than => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:less_than => 'global message'}}

    Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @topic.title = 1
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end
  
  def test_validates_numericality_of_less_than_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:less_than => 'global message'}}

    Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @topic.title = 1
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end
  
  
  # validates_associated
  
  def test_validates_associated_generates_message
    Topic.validates_associated :replies
    replied_topic.errors.expects(:generate_message).with(:replies, :invalid, {:value => replied_topic.replies, :default => nil})
    replied_topic.valid?
  end
  
  def test_validates_associated_generates_message_with_custom_default_message
    Topic.validates_associated :replies
    replied_topic.errors.expects(:generate_message).with(:replies, :invalid, {:value => replied_topic.replies, :default => nil})
    replied_topic.valid?
  end
  
  def test_validates_associated_finds_custom_model_key_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:custom => {:topic => {:replies => {:invalid => 'custom message'}}}}}
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:invalid => 'global message'}}

    Topic.validates_associated :replies
    replied_topic.valid?
    assert_equal 'custom message', replied_topic.errors.on(:replies)
  end
  
  def test_validates_associated_finds_global_default_translation
    I18n.backend.store_translations 'en-US', :active_record => {:error_messages => {:invalid => 'global message'}}

    Topic.validates_associated :replies
    replied_topic.valid?
    assert_equal 'global message', replied_topic.errors.on(:replies)
  end
end