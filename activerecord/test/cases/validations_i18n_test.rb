require "cases/helper"
require 'models/topic'
require 'models/reply'

class ActiveRecordValidationsI18nTests < ActiveSupport::TestCase
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

  def test_default_error_messages_is_deprecated
    assert_deprecated('ActiveRecord::Errors.default_error_messages') do
      ActiveRecord::Errors.default_error_messages
    end
  end

  def test_percent_s_interpolation_syntax_in_error_messages_still_works
    ActiveSupport::Deprecation.silence do
      result = I18n.t :does_not_exist, :default => "%s interpolation syntax is deprecated", :value => 'this'
      assert_equal result, "this interpolation syntax is deprecated"
    end
  end

  def test_percent_s_interpolation_syntax_in_error_messages_is_deprecated
    assert_deprecated('using %s in messages') do
      I18n.t :does_not_exist, :default => "%s interpolation syntax is deprected", :value => 'this'
    end
  end

  def test_percent_d_interpolation_syntax_in_error_messages_still_works
    ActiveSupport::Deprecation.silence do
      result = I18n.t :does_not_exist, :default => "%d interpolation syntaxes are deprecated", :count => 2
      assert_equal result, "2 interpolation syntaxes are deprecated"
    end
  end

  def test_percent_d_interpolation_syntax_in_error_messages_is_deprecated
    assert_deprecated('using %d in messages') do
      I18n.t :does_not_exist, :default => "%d interpolation syntaxes are deprected", :count => 2
    end
  end

  # ActiveRecord::Errors
  uses_mocha 'ActiveRecord::Errors' do

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
      @topic.errors.instance_variable_set :@errors, { 'title' => ['empty'] }
      I18n.expects(:translate).with(:"topic.title", :default => ['Title'], :scope => [:activerecord, :attributes], :count => 1).returns('Title')
      @topic.errors.full_messages :locale => 'en'
    end
  end

  # ActiveRecord::Validations
  uses_mocha 'ActiveRecord::Validations' do
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
  end

  # validates_confirmation_of w/o mocha

  def test_validates_confirmation_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:confirmation => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:confirmation => 'global message'}}}

    Topic.validates_confirmation_of :title
    @topic.title_confirmation = 'foo'
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_confirmation_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:confirmation => 'global message'}}}

    Topic.validates_confirmation_of :title
    @topic.title_confirmation = 'foo'
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_acceptance_of w/o mocha

  def test_validates_acceptance_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:accepted => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:accepted => 'global message'}}}

    Topic.validates_acceptance_of :title, :allow_nil => false
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_acceptance_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:accepted => 'global message'}}}

    Topic.validates_acceptance_of :title, :allow_nil => false
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_presence_of w/o mocha

  def test_validates_presence_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:blank => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:blank => 'global message'}}}

    Topic.validates_presence_of :title
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_presence_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:blank => 'global message'}}}

    Topic.validates_presence_of :title
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_length_of :within w/o mocha

  def test_validates_length_of_within_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:too_short => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:too_short => 'global message'}}}

    Topic.validates_length_of :title, :within => 3..5
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_length_of_within_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:too_short => 'global message'}}}

    Topic.validates_length_of :title, :within => 3..5
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_length_of :is w/o mocha

  def test_validates_length_of_is_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:wrong_length => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_length_of_is_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_uniqueness_of w/o mocha

  def test_validates_length_of_is_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:wrong_length => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_length_of_is_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Topic.validates_length_of :title, :is => 5
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end


  # validates_format_of w/o mocha

  def test_validates_format_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:invalid => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:invalid => 'global message'}}}

    Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_format_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:invalid => 'global message'}}}

    Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_inclusion_of w/o mocha

  def test_validates_inclusion_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:inclusion => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:inclusion => 'global message'}}}

    Topic.validates_inclusion_of :title, :in => %w(a b c)
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_inclusion_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:inclusion => 'global message'}}}

    Topic.validates_inclusion_of :title, :in => %w(a b c)
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_exclusion_of w/o mocha

  def test_validates_exclusion_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:exclusion => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:exclusion => 'global message'}}}

    Topic.validates_exclusion_of :title, :in => %w(a b c)
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_exclusion_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:exclusion => 'global message'}}}

    Topic.validates_exclusion_of :title, :in => %w(a b c)
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_numericality_of without :only_integer w/o mocha

  def test_validates_numericality_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:not_a_number => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Topic.validates_numericality_of :title
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_numericality_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_numericality_of with :only_integer w/o mocha

  def test_validates_numericality_of_only_integer_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:not_a_number => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_numericality_of_only_integer_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true
    @topic.title = 'a'
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_numericality_of :odd w/o mocha

  def test_validates_numericality_of_odd_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:odd => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:odd => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true, :odd => true
    @topic.title = 0
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_numericality_of_odd_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:odd => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true, :odd => true
    @topic.title = 0
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end

  # validates_numericality_of :less_than w/o mocha

  def test_validates_numericality_of_less_than_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:less_than => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:less_than => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @topic.title = 1
    @topic.valid?
    assert_equal 'custom message', @topic.errors.on(:title)
  end

  def test_validates_numericality_of_less_than_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:less_than => 'global message'}}}

    Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @topic.title = 1
    @topic.valid?
    assert_equal 'global message', @topic.errors.on(:title)
  end


  # validates_associated w/o mocha

  def test_validates_associated_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:replies => {:invalid => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:invalid => 'global message'}}}

    Topic.validates_associated :replies
    replied_topic.valid?
    assert_equal 'custom message', replied_topic.errors.on(:replies)
  end

  def test_validates_associated_finds_global_default_translation
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:invalid => 'global message'}}}

    Topic.validates_associated :replies
    replied_topic.valid?
    assert_equal 'global message', replied_topic.errors.on(:replies)
  end

  def test_validations_with_message_symbol_must_translate
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:messages => {:custom_error => "I am a custom error"}}}
    Topic.validates_presence_of :title, :message => :custom_error
    @topic.title = nil
    @topic.valid?
    assert_equal "I am a custom error", @topic.errors.on(:title)
  end

  def test_validates_with_message_symbol_must_translate_per_attribute
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:attributes => {:title => {:custom_error => "I am a custom error"}}}}}}
    Topic.validates_presence_of :title, :message => :custom_error
    @topic.title = nil
    @topic.valid?
    assert_equal "I am a custom error", @topic.errors.on(:title)
  end

  def test_validates_with_message_symbol_must_translate_per_model
    I18n.backend.store_translations 'en', :activerecord => {:errors => {:models => {:topic => {:custom_error => "I am a custom error"}}}}
    Topic.validates_presence_of :title, :message => :custom_error
    @topic.title = nil
    @topic.valid?
    assert_equal "I am a custom error", @topic.errors.on(:title)
  end

  def test_validates_with_message_string
    Topic.validates_presence_of :title, :message => "I am a custom error"
    @topic.title = nil
    @topic.valid?
    assert_equal "I am a custom error", @topic.errors.on(:title)
  end

end

class ActiveRecordValidationsGenerateMessageI18nTests < Test::Unit::TestCase
  def setup
    reset_callbacks Topic
    @topic = Topic.new
    I18n.backend.store_translations :'en', {
      :activerecord => {
        :errors => {
          :messages => {
            :inclusion => "is not included in the list",
            :exclusion => "is reserved",
            :invalid => "is invalid",
            :confirmation => "doesn't match confirmation",
            :accepted  => "must be accepted",
            :empty => "can't be empty",
            :blank => "can't be blank",
            :too_long => "is too long (maximum is {{count}} characters)",
            :too_short => "is too short (minimum is {{count}} characters)",
            :wrong_length => "is the wrong length (should be {{count}} characters)",
            :taken => "has already been taken",
            :not_a_number => "is not a number",
            :greater_than => "must be greater than {{count}}",
            :greater_than_or_equal_to => "must be greater than or equal to {{count}}",
            :equal_to => "must be equal to {{count}}",
            :less_than => "must be less than {{count}}",
            :less_than_or_equal_to => "must be less than or equal to {{count}}",
            :odd => "must be odd",
            :even => "must be even"
          }
        }
      }
    }
  end

  def reset_callbacks(*models)
    models.each do |model|
      model.instance_variable_set("@validate_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
      model.instance_variable_set("@validate_on_create_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
      model.instance_variable_set("@validate_on_update_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
    end
  end

  # validates_inclusion_of: generate_message(attr_name, :inclusion, :default => configuration[:message], :value => value)
  def test_generate_message_inclusion_with_default_message
    assert_equal 'is not included in the list', @topic.errors.generate_message(:title, :inclusion, :default => nil, :value => 'title')
  end

  def test_generate_message_inclusion_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :inclusion, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_exclusion_of: generate_message(attr_name, :exclusion, :default => configuration[:message], :value => value)
  def test_generate_message_exclusion_with_default_message
    assert_equal 'is reserved', @topic.errors.generate_message(:title, :exclusion, :default => nil, :value => 'title')
  end

  def test_generate_message_exclusion_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :exclusion, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_associated: generate_message(attr_name, :invalid, :default => configuration[:message], :value => value)
  # validates_format_of:  generate_message(attr_name, :invalid, :default => configuration[:message], :value => value)
  def test_generate_message_invalid_with_default_message
    assert_equal 'is invalid', @topic.errors.generate_message(:title, :invalid, :default => nil, :value => 'title')
  end

  def test_generate_message_invalid_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :invalid, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_confirmation_of: generate_message(attr_name, :confirmation, :default => configuration[:message])
  def test_generate_message_confirmation_with_default_message
    assert_equal "doesn't match confirmation", @topic.errors.generate_message(:title, :confirmation, :default => nil)
  end

  def test_generate_message_confirmation_with_custom_message
    assert_equal 'custom message', @topic.errors.generate_message(:title, :confirmation, :default => 'custom message')
  end

  # validates_acceptance_of: generate_message(attr_name, :accepted, :default => configuration[:message])
  def test_generate_message_accepted_with_default_message
    assert_equal "must be accepted", @topic.errors.generate_message(:title, :accepted, :default => nil)
  end

  def test_generate_message_accepted_with_custom_message
    assert_equal 'custom message', @topic.errors.generate_message(:title, :accepted, :default => 'custom message')
  end

  # add_on_empty: generate_message(attr, :empty, :default => custom_message)
  def test_generate_message_empty_with_default_message
    assert_equal "can't be empty", @topic.errors.generate_message(:title, :empty, :default => nil)
  end

  def test_generate_message_empty_with_custom_message
    assert_equal 'custom message', @topic.errors.generate_message(:title, :empty, :default => 'custom message')
  end

  # add_on_blank: generate_message(attr, :blank, :default => custom_message)
  def test_generate_message_blank_with_default_message
    assert_equal "can't be blank", @topic.errors.generate_message(:title, :blank, :default => nil)
  end

  def test_generate_message_blank_with_custom_message
    assert_equal 'custom message', @topic.errors.generate_message(:title, :blank, :default => 'custom message')
  end

  # validates_length_of: generate_message(attr, :too_long, :default => options[:too_long], :count => option_value.end)
  def test_generate_message_too_long_with_default_message
    assert_equal "is too long (maximum is 10 characters)", @topic.errors.generate_message(:title, :too_long, :default => nil, :count => 10)
  end

  def test_generate_message_too_long_with_custom_message
    assert_equal 'custom message 10', @topic.errors.generate_message(:title, :too_long, :default => 'custom message {{count}}', :count => 10)
  end

  # validates_length_of: generate_message(attr, :too_short, :default => options[:too_short], :count => option_value.begin)
  def test_generate_message_too_short_with_default_message
    assert_equal "is too short (minimum is 10 characters)", @topic.errors.generate_message(:title, :too_short, :default => nil, :count => 10)
  end

  def test_generate_message_too_short_with_custom_message
    assert_equal 'custom message 10', @topic.errors.generate_message(:title, :too_short, :default => 'custom message {{count}}', :count => 10)
  end

  # validates_length_of: generate_message(attr, key, :default => custom_message, :count => option_value)
  def test_generate_message_wrong_length_with_default_message
    assert_equal "is the wrong length (should be 10 characters)", @topic.errors.generate_message(:title, :wrong_length, :default => nil, :count => 10)
  end

  def test_generate_message_wrong_length_with_custom_message
    assert_equal 'custom message 10', @topic.errors.generate_message(:title, :wrong_length, :default => 'custom message {{count}}', :count => 10)
  end

  # validates_uniqueness_of: generate_message(attr_name, :taken, :default => configuration[:message])
  def test_generate_message_taken_with_default_message
    assert_equal "has already been taken", @topic.errors.generate_message(:title, :taken, :default => nil, :value => 'title')
  end

  def test_generate_message_taken_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :taken, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_numericality_of: generate_message(attr_name, :not_a_number, :value => raw_value, :default => configuration[:message])
  def test_generate_message_not_a_number_with_default_message
    assert_equal "is not a number", @topic.errors.generate_message(:title, :not_a_number, :default => nil, :value => 'title')
  end

  def test_generate_message_not_a_number_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :not_a_number, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_numericality_of: generate_message(attr_name, option, :value => raw_value, :default => configuration[:message])
  def test_generate_message_greater_than_with_default_message
    assert_equal "must be greater than 10", @topic.errors.generate_message(:title, :greater_than, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_greater_than_or_equal_to_with_default_message
    assert_equal "must be greater than or equal to 10", @topic.errors.generate_message(:title, :greater_than_or_equal_to, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_equal_to_with_default_message
    assert_equal "must be equal to 10", @topic.errors.generate_message(:title, :equal_to, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_less_than_with_default_message
    assert_equal "must be less than 10", @topic.errors.generate_message(:title, :less_than, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_less_than_or_equal_to_with_default_message
    assert_equal "must be less than or equal to 10", @topic.errors.generate_message(:title, :less_than_or_equal_to, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_odd_with_default_message
    assert_equal "must be odd", @topic.errors.generate_message(:title, :odd, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_even_with_default_message
    assert_equal "must be even", @topic.errors.generate_message(:title, :even, :default => nil, :value => 'title', :count => 10)
  end

end
