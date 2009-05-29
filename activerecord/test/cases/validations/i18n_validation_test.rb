require "cases/helper"
require 'models/topic'
require 'models/reply'

class I18nValidationTest < ActiveRecord::TestCase
  def setup
    reset_callbacks Topic
    @topic = Topic.new
    @old_load_path, @old_backend = I18n.load_path, I18n.backend
    I18n.load_path.clear
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations('en', :activerecord => {:errors => {:messages => {:custom => nil}}})
  end

  def teardown
    reset_callbacks Topic
    I18n.load_path.replace @old_load_path
    I18n.backend = @old_backend
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

  def test_percent_s_interpolation_syntax_in_error_messages_was_deprecated
    assert_not_deprecated do
      default = "%s interpolation syntax was deprecated"
      assert_equal default, I18n.t(:does_not_exist, :default => default, :value => 'this')
    end
  end

  def test_percent_d_interpolation_syntax_in_error_messages_was_deprecated
    assert_not_deprecated do
      default = "%d interpolation syntaxes are deprecated"
      assert_equal default, I18n.t(:does_not_exist, :default => default, :count => 2)
    end
  end

  # ActiveRecord::Errors
  def test_errors_generate_message_translates_custom_model_attribute_key
    I18n.expects(:translate).with(
      :topic,
      { :count => 1,
        :default => ['Topic'],
        :scope => [:activerecord, :models]
      }
    ).returns('Topic')

    I18n.expects(:translate).with(
      :"topic.title",
      { :count => 1,
        :default => ['Title'],
        :scope => [:activerecord, :attributes]
      }
    ).returns('Title')

    I18n.expects(:translate).with(
      :"models.topic.attributes.title.invalid",
      :value => nil,
      :scope => [:activerecord, :errors],
      :default => [
        :"models.topic.invalid",
        'default from class def error 1',
        :"messages.invalid"],
      :attribute => "Title",
      :model => "Topic"
    ).returns('default from class def error 1')

    @topic.errors.generate_message :title, :invalid, :default => 'default from class def error 1'
  end

  def test_errors_generate_message_translates_custom_model_attribute_keys_with_sti

    I18n.expects(:translate).with(
      :reply,
      { :count => 1,
        :default => [:topic, 'Reply'],
        :scope => [:activerecord, :models]
      }
    ).returns('Reply')

    I18n.expects(:translate).with(
      :"reply.title",
      { :count => 1,
        :default => [:'topic.title', 'Title'],
        :scope => [:activerecord, :attributes]
      }
    ).returns('Title')

    I18n.expects(:translate).with(
      :"models.reply.attributes.title.invalid",
      :value => nil,
      :scope => [:activerecord, :errors],
      :default => [
        :"models.reply.invalid",
        :"models.topic.attributes.title.invalid",
        :"models.topic.invalid",
        'default from class def',
        :"messages.invalid"],
      :model => 'Reply',
      :attribute => 'Title'
    ).returns("default from class def")

    Reply.new.errors.generate_message :title, :invalid, :default => 'default from class def'

  end

  # validates_uniqueness_of w/ mocha

  def test_validates_uniqueness_of_generates_message
    Topic.validates_uniqueness_of :title
    @topic.title = unique_topic.title
    @topic.errors.expects(:generate_message).with(:title, :taken, {:default => nil, :value => 'unique!'})
    @topic.valid?
  end

  def test_validates_uniqueness_of_generates_message_with_custom_default_message
    Topic.validates_uniqueness_of :title, :message => 'custom'
    @topic.title = unique_topic.title
    @topic.errors.expects(:generate_message).with(:title, :taken, {:default => 'custom', :value => 'unique!'})
    @topic.valid?
  end

  # validates_associated w/ mocha

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

  # validates_associated w/o mocha

  def test_validates_associated_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:replies => {:invalid => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:invalid => 'global message'}}}

    Topic.validates_associated :replies
    replied_topic.valid?
    assert_equal ['custom message'], replied_topic.errors[:replies]
  end

  def test_validates_associated_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:invalid => 'global message'}}}

    Topic.validates_associated :replies
    replied_topic.valid?
    assert_equal ['global message'], replied_topic.errors[:replies]
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
    @topic.errors.add('title', 'empty')
    I18n.expects(:translate).with(:"topic.title", :default => ['Title'], :scope => [:activerecord, :attributes], :count => 1).returns('Title')
    @topic.errors.full_messages :locale => 'en'
  end

  # ActiveRecord::Validations
  # validates_confirmation_of w/ mocha
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

  # validates_acceptance_of w/ mocha

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

  # validates_presence_of w/ mocha

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

  def test_validates_length_of_within_generates_message_with_title_too_short
    Topic.validates_length_of :title, :within => 3..5
    @topic.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => nil})
    @topic.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_short_and_custom_default_message
    Topic.validates_length_of :title, :within => 3..5, :too_short => 'custom'
    @topic.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => 'custom'})
    @topic.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_long
    Topic.validates_length_of :title, :within => 3..5
    @topic.title = 'this title is too long'
    @topic.errors.expects(:generate_message).with(:title, :too_long, {:count => 5, :default => nil})
    @topic.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_long_and_custom_default_message
    Topic.validates_length_of :title, :within => 3..5, :too_long => 'custom'
    @topic.title = 'this title is too long'
    @topic.errors.expects(:generate_message).with(:title, :too_long, {:count => 5, :default => 'custom'})
    @topic.valid?
  end

  # validates_length_of :within w/ mocha

  def test_validates_length_of_within_generates_message_with_title_too_short
    Topic.validates_length_of :title, :within => 3..5
    @topic.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => nil})
    @topic.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_short_and_custom_default_message
    Topic.validates_length_of :title, :within => 3..5, :too_short => 'custom'
    @topic.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => 'custom'})
    @topic.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_long
    Topic.validates_length_of :title, :within => 3..5
    @topic.title = 'this title is too long'
    @topic.errors.expects(:generate_message).with(:title, :too_long, {:count => 5, :default => nil})
    @topic.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_long_and_custom_default_message
    Topic.validates_length_of :title, :within => 3..5, :too_long => 'custom'
    @topic.title = 'this title is too long'
    @topic.errors.expects(:generate_message).with(:title, :too_long, {:count => 5, :default => 'custom'})
    @topic.valid?
  end

  # validates_length_of :is w/ mocha

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

  # validates_format_of w/ mocha

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

  # validates_inclusion_of w/ mocha

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

  # validates_exclusion_of w/ mocha

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

  # validates_numericality_of without :only_integer w/ mocha

  def test_validates_numericality_of_generates_message
    Topic.validates_numericality_of :title
    @topic.title = 'a'
    @topic.errors.expects(:generate_message).with(:title, :not_a_number, {:value => 'a', :default => nil})
    @topic.valid?
  end

  def test_validates_numericality_of_generates_message_with_custom_default_message
    Topic.validates_numericality_of :title, :message => 'custom'
    @topic.title = 'a'
    @topic.errors.expects(:generate_message).with(:title, :not_a_number, {:value => 'a', :default => 'custom'})
    @topic.valid?
  end

  # validates_numericality_of with :only_integer w/ mocha

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

  # validates_numericality_of :odd w/ mocha

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

  # validates_numericality_of :less_than w/ mocha

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

  # validates_confirmation_of w/o mocha

  def test_validates_confirmation_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:confirmation => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:confirmation => 'global message'}}}

    Topic.validates_confirmation_of :title
    @topic.title_confirmation = 'foo'
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_confirmation_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:confirmation => 'global message'}}}

    Topic.validates_confirmation_of :title
    @topic.title_confirmation = 'foo'
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_acceptance_of w/o mocha

  def test_validates_acceptance_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:accepted => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:accepted => 'global message'}}}

    Topic.validates_acceptance_of :title, :allow_nil => false
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_acceptance_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:accepted => 'global message'}}}

    Topic.validates_acceptance_of :title, :allow_nil => false
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_presence_of w/o mocha

  def test_validates_presence_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:blank => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:blank => 'global message'}}}

    Topic.validates_presence_of :title
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_presence_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:blank => 'global message'}}}

    Topic.validates_presence_of :title
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_length_of :within w/o mocha

  def test_validates_length_of_within_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:too_short => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:too_short => 'global message'}}}

    Topic.validates_length_of :title, :within => 3..5
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_length_of_within_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:too_short => 'global message'}}}

    Topic.validates_length_of :title, :within => 3..5
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_length_of :is w/o mocha

  def test_validates_length_of_is_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:wrong_length => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_length_of_is_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  def test_validates_length_of_is_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:wrong_length => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_length_of_is_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end


  # validates_format_of w/o mocha

  def test_validates_format_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:invalid => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:invalid => 'global message'}}}

    Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_format_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:invalid => 'global message'}}}

    Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_inclusion_of w/o mocha

  def test_validates_inclusion_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:inclusion => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:inclusion => 'global message'}}}

    Topic.validates_inclusion_of :title, :in => %w(a b c)
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_inclusion_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:inclusion => 'global message'}}}

    Topic.validates_inclusion_of :title, :in => %w(a b c)
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_exclusion_of w/o mocha

  def test_validates_exclusion_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:exclusion => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:exclusion => 'global message'}}}

    Topic.validates_exclusion_of :title, :in => %w(a b c)
    @topic.title = 'a'
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_exclusion_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:exclusion => 'global message'}}}

    Topic.validates_exclusion_of :title, :in => %w(a b c)
    @topic.title = 'a'
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_numericality_of without :only_integer w/o mocha

  def test_validates_numericality_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:not_a_number => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Topic.validates_numericality_of :title
    @topic.title = 'a'
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_numericality_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true
    @topic.title = 'a'
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_numericality_of with :only_integer w/o mocha

  def test_validates_numericality_of_only_integer_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:not_a_number => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true
    @topic.title = 'a'
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_numericality_of_only_integer_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true
    @topic.title = 'a'
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_numericality_of :odd w/o mocha

  def test_validates_numericality_of_odd_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:odd => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:odd => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true, :odd => true
    @topic.title = 0
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_numericality_of_odd_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:odd => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true, :odd => true
    @topic.title = 0
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  # validates_numericality_of :less_than w/o mocha

  def test_validates_numericality_of_less_than_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:less_than => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:less_than => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @topic.title = 1
    @topic.valid?
    assert_equal ['custom message'], @topic.errors[:title]
  end

  def test_validates_numericality_of_less_than_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:less_than => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @topic.title = 1
    @topic.valid?
    assert_equal ['global message'], @topic.errors[:title]
  end

  def test_validations_with_message_symbol_must_translate
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:custom_error => "I am a custom error"}}}
    Topic.validates_presence_of :title, :message => :custom_error
    @topic.title = nil
    @topic.valid?
    assert_equal ["I am a custom error"], @topic.errors[:title]
  end

  def test_validates_with_message_symbol_must_translate_per_attribute
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:custom_error => "I am a custom error"}}}}}}
    Topic.validates_presence_of :title, :message => :custom_error
    @topic.title = nil
    @topic.valid?
    assert_equal ["I am a custom error"], @topic.errors[:title]
  end

  def test_validates_with_message_symbol_must_translate_per_model
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:custom_error => "I am a custom error"}}}}
    Topic.validates_presence_of :title, :message => :custom_error
    @topic.title = nil
    @topic.valid?
    assert_equal ["I am a custom error"], @topic.errors[:title]
  end

  def test_validates_with_message_string
    Topic.validates_presence_of :title, :message => "I am a custom error"
    @topic.title = nil
    @topic.valid?
    assert_equal ["I am a custom error"], @topic.errors[:title]
  end
end
