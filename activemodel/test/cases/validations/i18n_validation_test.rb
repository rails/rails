require "cases/helper"
require 'cases/tests_database'

require 'models/person'

class I18nValidationTest < ActiveModel::TestCase
  include ActiveModel::TestsDatabase

  def setup
    reset_callbacks Person

    @person = Person.new

    @old_load_path, @old_backend = I18n.load_path, I18n.backend
    I18n.load_path.clear
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations('en', :activemodel => {:errors => {:messages => {:custom => nil}}})
  end

  def teardown
    reset_callbacks Person
    I18n.load_path.replace @old_load_path
    I18n.backend = @old_backend
  end

  def reset_callbacks(*models)
    models.each do |model|
      model.instance_variable_set("@validate_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
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

  def test_errors_add_on_empty_generates_message
    @person.errors.expects(:generate_message).with(:title, :empty, {:default => nil})
    @person.errors.add_on_empty :title
  end

  def test_errors_add_on_empty_generates_message_with_custom_default_message
    @person.errors.expects(:generate_message).with(:title, :empty, {:default => 'custom'})
    @person.errors.add_on_empty :title, 'custom'
  end

  def test_errors_add_on_blank_generates_message
    @person.errors.expects(:generate_message).with(:title, :blank, {:default => nil})
    @person.errors.add_on_blank :title
  end

  def test_errors_add_on_blank_generates_message_with_custom_default_message
    @person.errors.expects(:generate_message).with(:title, :blank, {:default => 'custom'})
    @person.errors.add_on_blank :title, 'custom'
  end

  # ActiveRecord::Validations
  # validates_confirmation_of w/ mocha
  def test_validates_confirmation_of_generates_message
    Person.validates_confirmation_of :title
    @person.title_confirmation = 'foo'
    @person.errors.expects(:generate_message).with(:title, :confirmation, {:default => nil})
    @person.valid?
  end

  def test_validates_confirmation_of_generates_message_with_custom_default_message
    Person.validates_confirmation_of :title, :message => 'custom'
    @person.title_confirmation = 'foo'
    @person.errors.expects(:generate_message).with(:title, :confirmation, {:default => 'custom'})
    @person.valid?
  end

  # validates_acceptance_of w/ mocha

  def test_validates_acceptance_of_generates_message
    Person.validates_acceptance_of :title, :allow_nil => false
    @person.errors.expects(:generate_message).with(:title, :accepted, {:default => nil})
    @person.valid?
  end

  def test_validates_acceptance_of_generates_message_with_custom_default_message
    Person.validates_acceptance_of :title, :message => 'custom', :allow_nil => false
    @person.errors.expects(:generate_message).with(:title, :accepted, {:default => 'custom'})
    @person.valid?
  end

  # validates_presence_of w/ mocha

  def test_validates_presence_of_generates_message
    Person.validates_presence_of :title
    @person.errors.expects(:generate_message).with(:title, :blank, {:default => nil})
    @person.valid?
  end

  def test_validates_presence_of_generates_message_with_custom_default_message
    Person.validates_presence_of :title, :message => 'custom'
    @person.errors.expects(:generate_message).with(:title, :blank, {:default => 'custom'})
    @person.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_short
    Person.validates_length_of :title, :within => 3..5
    @person.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => nil})
    @person.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_short_and_custom_default_message
    Person.validates_length_of :title, :within => 3..5, :too_short => 'custom'
    @person.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => 'custom'})
    @person.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_long
    Person.validates_length_of :title, :within => 3..5
    @person.title = 'this title is too long'
    @person.errors.expects(:generate_message).with(:title, :too_long, {:count => 5, :default => nil})
    @person.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_long_and_custom_default_message
    Person.validates_length_of :title, :within => 3..5, :too_long => 'custom'
    @person.title = 'this title is too long'
    @person.errors.expects(:generate_message).with(:title, :too_long, {:count => 5, :default => 'custom'})
    @person.valid?
  end

  # validates_length_of :within w/ mocha

  def test_validates_length_of_within_generates_message_with_title_too_short
    Person.validates_length_of :title, :within => 3..5
    @person.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => nil})
    @person.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_short_and_custom_default_message
    Person.validates_length_of :title, :within => 3..5, :too_short => 'custom'
    @person.errors.expects(:generate_message).with(:title, :too_short, {:count => 3, :default => 'custom'})
    @person.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_long
    Person.validates_length_of :title, :within => 3..5
    @person.title = 'this title is too long'
    @person.errors.expects(:generate_message).with(:title, :too_long, {:count => 5, :default => nil})
    @person.valid?
  end

  def test_validates_length_of_within_generates_message_with_title_too_long_and_custom_default_message
    Person.validates_length_of :title, :within => 3..5, :too_long => 'custom'
    @person.title = 'this title is too long'
    @person.errors.expects(:generate_message).with(:title, :too_long, {:count => 5, :default => 'custom'})
    @person.valid?
  end

  # validates_length_of :is w/ mocha

  def test_validates_length_of_is_generates_message
    Person.validates_length_of :title, :is => 5
    @person.errors.expects(:generate_message).with(:title, :wrong_length, {:count => 5, :default => nil})
    @person.valid?
  end

  def test_validates_length_of_is_generates_message_with_custom_default_message
    Person.validates_length_of :title, :is => 5, :message => 'custom'
    @person.errors.expects(:generate_message).with(:title, :wrong_length, {:count => 5, :default => 'custom'})
    @person.valid?
  end

  # validates_format_of w/ mocha

  def test_validates_format_of_generates_message
    Person.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @person.title = '72x'
    @person.errors.expects(:generate_message).with(:title, :invalid, {:value => '72x', :default => nil})
    @person.valid?
  end

  def test_validates_format_of_generates_message_with_custom_default_message
    Person.validates_format_of :title, :with => /^[1-9][0-9]*$/, :message => 'custom'
    @person.title = '72x'
    @person.errors.expects(:generate_message).with(:title, :invalid, {:value => '72x', :default => 'custom'})
    @person.valid?
  end

  # validates_inclusion_of w/ mocha

  def test_validates_inclusion_of_generates_message
    Person.validates_inclusion_of :title, :in => %w(a b c)
    @person.title = 'z'
    @person.errors.expects(:generate_message).with(:title, :inclusion, {:value => 'z', :default => nil})
    @person.valid?
  end

  def test_validates_inclusion_of_generates_message_with_custom_default_message
    Person.validates_inclusion_of :title, :in => %w(a b c), :message => 'custom'
    @person.title = 'z'
    @person.errors.expects(:generate_message).with(:title, :inclusion, {:value => 'z', :default => 'custom'})
    @person.valid?
  end

  # validates_exclusion_of w/ mocha

  def test_validates_exclusion_of_generates_message
    Person.validates_exclusion_of :title, :in => %w(a b c)
    @person.title = 'a'
    @person.errors.expects(:generate_message).with(:title, :exclusion, {:value => 'a', :default => nil})
    @person.valid?
  end

  def test_validates_exclusion_of_generates_message_with_custom_default_message
    Person.validates_exclusion_of :title, :in => %w(a b c), :message => 'custom'
    @person.title = 'a'
    @person.errors.expects(:generate_message).with(:title, :exclusion, {:value => 'a', :default => 'custom'})
    @person.valid?
  end

  # validates_numericality_of without :only_integer w/ mocha

  def test_validates_numericality_of_generates_message
    Person.validates_numericality_of :title
    @person.title = 'a'
    @person.errors.expects(:generate_message).with(:title, :not_a_number, {:value => 'a', :default => nil})
    @person.valid?
  end

  def test_validates_numericality_of_generates_message_with_custom_default_message
    Person.validates_numericality_of :title, :message => 'custom'
    @person.title = 'a'
    @person.errors.expects(:generate_message).with(:title, :not_a_number, {:value => 'a', :default => 'custom'})
    @person.valid?
  end

  # validates_numericality_of with :only_integer w/ mocha

  def test_validates_numericality_of_only_integer_generates_message
    Person.validates_numericality_of :title, :only_integer => true
    @person.title = 'a'
    @person.errors.expects(:generate_message).with(:title, :not_a_number, {:value => 'a', :default => nil})
    @person.valid?
  end

  def test_validates_numericality_of_only_integer_generates_message_with_custom_default_message
    Person.validates_numericality_of :title, :only_integer => true, :message => 'custom'
    @person.title = 'a'
    @person.errors.expects(:generate_message).with(:title, :not_a_number, {:value => 'a', :default => 'custom'})
    @person.valid?
  end

  # validates_numericality_of :odd w/ mocha

  def test_validates_numericality_of_odd_generates_message
    Person.validates_numericality_of :title, :only_integer => true, :odd => true
    @person.title = 0
    @person.errors.expects(:generate_message).with(:title, :odd, {:value => 0, :default => nil})
    @person.valid?
  end

  def test_validates_numericality_of_odd_generates_message_with_custom_default_message
    Person.validates_numericality_of :title, :only_integer => true, :odd => true, :message => 'custom'
    @person.title = 0
    @person.errors.expects(:generate_message).with(:title, :odd, {:value => 0, :default => 'custom'})
    @person.valid?
  end

  # validates_numericality_of :less_than w/ mocha

  def test_validates_numericality_of_less_than_generates_message
    Person.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @person.title = 1
    @person.errors.expects(:generate_message).with(:title, :less_than, {:value => 1, :count => 0, :default => nil})
    @person.valid?
  end

  def test_validates_numericality_of_odd_generates_message_with_custom_default_message
    Person.validates_numericality_of :title, :only_integer => true, :less_than => 0, :message => 'custom'
    @person.title = 1
    @person.errors.expects(:generate_message).with(:title, :less_than, {:value => 1, :count => 0, :default => 'custom'})
    @person.valid?
  end

  # validates_confirmation_of w/o mocha

  def test_validates_confirmation_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:confirmation => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:confirmation => 'global message'}}}

    Person.validates_confirmation_of :title
    @person.title_confirmation = 'foo'
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_confirmation_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:confirmation => 'global message'}}}

    Person.validates_confirmation_of :title
    @person.title_confirmation = 'foo'
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_acceptance_of w/o mocha

  def test_validates_acceptance_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:accepted => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:accepted => 'global message'}}}

    Person.validates_acceptance_of :title, :allow_nil => false
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_acceptance_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:accepted => 'global message'}}}

    Person.validates_acceptance_of :title, :allow_nil => false
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_presence_of w/o mocha

  def test_validates_presence_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:blank => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:blank => 'global message'}}}

    Person.validates_presence_of :title
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_presence_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:blank => 'global message'}}}

    Person.validates_presence_of :title
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_length_of :within w/o mocha

  def test_validates_length_of_within_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:too_short => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:too_short => 'global message'}}}

    Person.validates_length_of :title, :within => 3..5
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_length_of_within_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:too_short => 'global message'}}}

    Person.validates_length_of :title, :within => 3..5
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_length_of :is w/o mocha

  def test_validates_length_of_is_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:wrong_length => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Person.validates_length_of :title, :is => 5
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_length_of_is_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Person.validates_length_of :title, :is => 5
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  def test_validates_length_of_is_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:wrong_length => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Person.validates_length_of :title, :is => 5
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_length_of_is_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:wrong_length => 'global message'}}}

    Person.validates_length_of :title, :is => 5
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end


  # validates_format_of w/o mocha

  def test_validates_format_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:invalid => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:invalid => 'global message'}}}

    Person.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_format_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:invalid => 'global message'}}}

    Person.validates_format_of :title, :with => /^[1-9][0-9]*$/
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_inclusion_of w/o mocha

  def test_validates_inclusion_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:inclusion => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:inclusion => 'global message'}}}

    Person.validates_inclusion_of :title, :in => %w(a b c)
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_inclusion_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:inclusion => 'global message'}}}

    Person.validates_inclusion_of :title, :in => %w(a b c)
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_exclusion_of w/o mocha

  def test_validates_exclusion_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:exclusion => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:exclusion => 'global message'}}}

    Person.validates_exclusion_of :title, :in => %w(a b c)
    @person.title = 'a'
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_exclusion_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:exclusion => 'global message'}}}

    Person.validates_exclusion_of :title, :in => %w(a b c)
    @person.title = 'a'
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_numericality_of without :only_integer w/o mocha

  def test_validates_numericality_of_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:not_a_number => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Person.validates_numericality_of :title
    @person.title = 'a'
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_numericality_of_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Person.validates_numericality_of :title, :only_integer => true
    @person.title = 'a'
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_numericality_of with :only_integer w/o mocha

  def test_validates_numericality_of_only_integer_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:not_a_number => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Person.validates_numericality_of :title, :only_integer => true
    @person.title = 'a'
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_numericality_of_only_integer_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:not_a_number => 'global message'}}}

    Person.validates_numericality_of :title, :only_integer => true
    @person.title = 'a'
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_numericality_of :odd w/o mocha

  def test_validates_numericality_of_odd_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:odd => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:odd => 'global message'}}}

    Person.validates_numericality_of :title, :only_integer => true, :odd => true
    @person.title = 0
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_numericality_of_odd_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:odd => 'global message'}}}

    Person.validates_numericality_of :title, :only_integer => true, :odd => true
    @person.title = 0
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  # validates_numericality_of :less_than w/o mocha

  def test_validates_numericality_of_less_than_finds_custom_model_key_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:less_than => 'custom message'}}}}}}
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:less_than => 'global message'}}}

    Person.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @person.title = 1
    @person.valid?
    assert_equal ['custom message'], @person.errors[:title]
  end

  def test_validates_numericality_of_less_than_finds_global_default_translation
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:less_than => 'global message'}}}

    Person.validates_numericality_of :title, :only_integer => true, :less_than => 0
    @person.title = 1
    @person.valid?
    assert_equal ['global message'], @person.errors[:title]
  end

  def test_validations_with_message_symbol_must_translate
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:messages => {:custom_error => "I am a custom error"}}}
    Person.validates_presence_of :title, :message => :custom_error
    @person.title = nil
    @person.valid?
    assert_equal ["I am a custom error"], @person.errors[:title]
  end

  def test_validates_with_message_symbol_must_translate_per_attribute
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:attributes => {:title => {:custom_error => "I am a custom error"}}}}}}
    Person.validates_presence_of :title, :message => :custom_error
    @person.title = nil
    @person.valid?
    assert_equal ["I am a custom error"], @person.errors[:title]
  end

  def test_validates_with_message_symbol_must_translate_per_model
    I18n.backend.store_translations 'en', :activemodel => {:errors => {:models => {:person => {:custom_error => "I am a custom error"}}}}
    Person.validates_presence_of :title, :message => :custom_error
    @person.title = nil
    @person.valid?
    assert_equal ["I am a custom error"], @person.errors[:title]
  end

  def test_validates_with_message_string
    Person.validates_presence_of :title, :message => "I am a custom error"
    @person.title = nil
    @person.valid?
    assert_equal ["I am a custom error"], @person.errors[:title]
  end

end