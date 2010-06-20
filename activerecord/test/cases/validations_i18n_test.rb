require "cases/helper"
require 'models/topic'
require 'models/reply'
require 'models/person'

module ActiveRecordValidationsI18nTestHelper
  def store_translations(*args)
    data = args.extract_options!
    locale = args.shift || 'en'
    I18n.backend.send(:init_translations)
    I18n.backend.store_translations(locale, :activerecord => data)
  end

  def delete_translation(key)
    I18n.backend.instance_eval do
      keys = I18n.send(:normalize_translation_keys, 'en', key, nil)
      keys.inject(translations) { |result, k| keys.last == k ? result.delete(k.to_sym) : result[k.to_sym] }
    end
  end

  def reset_callbacks(*models)
    models.each do |model|
      model.instance_variable_set("@validate_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
      model.instance_variable_set("@validate_on_create_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
      model.instance_variable_set("@validate_on_update_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
    end
  end
end


# ACTIVERECORD VALIDATIONS
#
# For each validation:
#
# * test expect that it adds an error with the appropriate arguments
# * test that it looks up the correct default message

class ActiveRecordValidationsI18nTests < ActiveSupport::TestCase
  include ActiveRecordValidationsI18nTestHelper

  def setup
    reset_callbacks(Topic)
    @topic = Topic.new
    @reply = Reply.new
    @old_load_path, @old_backend = I18n.load_path, I18n.backend
    I18n.load_path.clear
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations('en', :activerecord => {:errors => {:messages => {:custom => nil}}})
  end

  def teardown
    reset_callbacks(Topic)
    I18n.load_path.replace(@old_load_path)
    I18n.backend = @old_backend
  end

  def expect_error_added(model, attribute, type, options)
    model.errors.expects(:add).with(attribute, type, options)
    yield
    model.valid?
  end

  def assert_message_translations(model, attribute, type, &block)
    assert_default_message_translation(model, attribute, type, &block)
    reset_callbacks(model.class)
    model.errors.clear
    assert_custom_message_translation(model, attribute, type, &block)
  end

  def assert_custom_message_translation(model, attribute, type)
    store_translations(:errors => { :models => { model.class.name.underscore => { :attributes => { attribute => { type => 'custom message' } } } } })
    yield
    model.valid?
    assert_equal 'custom message', model.errors.on(attribute)
  end

  def assert_default_message_translation(model, attribute, type)
    store_translations(:errors => { :messages => { type => 'default message' } })
    yield
    model.valid?
    assert_equal 'default message', model.errors.on(attribute)
  end

  def unique_topic
    @unique ||= Topic.create(:title => 'unique!')
  end

  def replied_topic
    @replied_topic ||= begin
      topic = Topic.create(:title => "topic")
      topic.replies << Reply.new
      topic
    end
  end

  # validates_confirmation_of

  test "#validates_confirmation_of given no custom message" do
    expect_error_added(@topic, :title, :confirmation, :default => nil) do
      Topic.validates_confirmation_of :title
      @topic.title = 'title'
      @topic.title_confirmation = 'foo'
    end
  end

  test "#validates_confirmation_of given a custom message" do
    expect_error_added(@topic, :title, :confirmation, :default => 'custom') do
      Topic.validates_confirmation_of :title, :message => 'custom'
      @topic.title_confirmation = 'foo'
    end
  end

  test "#validates_confirmation_of finds the correct message translations" do
    assert_message_translations(@topic, :title, :confirmation) do
      Topic.validates_confirmation_of :title
      @topic.title_confirmation = 'foo'
    end
  end

  # validates_acceptance_of

  test "#validates_acceptance_of given no custom message" do
    expect_error_added(@topic, :title, :accepted, :default => nil) do
      Topic.validates_acceptance_of :title, :allow_nil => false
    end
  end

  test "#validates_acceptance_of given a custom message" do
    expect_error_added(@topic, :title, :accepted, :default => 'custom') do
      Topic.validates_acceptance_of :title, :message => 'custom', :allow_nil => false
    end
  end

  test "#validates_acceptance_of finds the correct message translations" do
    assert_message_translations(@topic, :title, :accepted) do
      Topic.validates_acceptance_of :title, :allow_nil => false
    end
  end

  # validates_presence_of

  test "#validates_presence_of given no custom message" do
    expect_error_added(@topic, :title, :blank, :default => nil) do
      Topic.validates_presence_of :title
    end
  end

  test "#validates_presence_of given a custom message" do
    expect_error_added(@topic, :title, :blank, :default => 'custom') do
      Topic.validates_presence_of :title, :message => 'custom'
    end
  end

  test "#validates_presence_of finds the correct message translations" do
    assert_message_translations(@topic, :title, :blank) do
      Topic.validates_presence_of :title
    end
  end

  # validates_length_of :too_short

  test "#validates_length_of (:too_short) and no custom message" do
    expect_error_added(@topic, :title, :too_short, :default => nil, :count => 3) do
      Topic.validates_length_of :title, :within => 3..5
    end
  end

  test "#validates_length_of (:too_short) and a custom message" do
    expect_error_added(@topic, :title, :too_short, :default => 'custom', :count => 3) do
      Topic.validates_length_of :title, :within => 3..5, :too_short => 'custom'
    end
  end

  test "#validates_length_of (:too_short) finds the correct message translations" do
    assert_message_translations(@topic, :title, :too_short) do
      Topic.validates_length_of :title, :within => 3..5
    end
  end

  # validates_length_of :too_long

  test "#validates_length_of (:too_long) and no custom message" do
    expect_error_added(@topic, :title, :too_long, :default => nil, :count => 5) do
      Topic.validates_length_of :title, :within => 3..5
      @topic.title = 'this title is too long'
    end
  end

  test "#validates_length_of (:too_long) and a custom message" do
    expect_error_added(@topic, :title, :too_long, :default => 'custom', :count => 5) do
      Topic.validates_length_of :title, :within => 3..5, :too_long => 'custom'
      @topic.title = 'this title is too long'
    end
  end

  test "#validates_length_of (:too_long) finds the correct message translations" do
    assert_message_translations(@topic, :title, :too_long) do
      Topic.validates_length_of :title, :within => 3..5
      @topic.title = 'this title is too long'
    end
  end

  # validates_length_of :is

  test "#validates_length_of (:is) and no custom message" do
    expect_error_added(@topic, :title, :wrong_length, :default => nil, :count => 5) do
      Topic.validates_length_of :title, :is => 5
      @topic.title = 'this title has the wrong length'
    end
  end

  test "#validates_length_of (:is) and a custom message" do
    expect_error_added(@topic, :title, :wrong_length, :default => 'custom', :count => 5) do
      Topic.validates_length_of :title, :is => 5, :wrong_length => 'custom'
      @topic.title = 'this title has the wrong length'
    end
  end

  test "#validates_length_of (:is) finds the correct message translations" do
    assert_message_translations(@topic, :title, :wrong_length) do
      Topic.validates_length_of :title, :is => 5
      @topic.title = 'this title has the wrong length'
    end
  end

  # validates_uniqueness_of

  test "#validates_uniqueness_of and no custom message" do
    expect_error_added(@topic, :title, :taken, :default => nil, :value => 'unique!') do
      Topic.validates_uniqueness_of :title
      @topic.title = unique_topic.title
    end
  end

  test "#validates_uniqueness_of and a custom message" do
    expect_error_added(@topic, :title, :taken, :default => 'custom', :value => 'unique!') do
      Topic.validates_uniqueness_of :title, :message => 'custom'
      @topic.title = unique_topic.title
    end
  end

  test "#validates_uniqueness_of finds the correct message translations" do
    assert_message_translations(@topic, :title, :taken) do
      Topic.validates_uniqueness_of :title
      @topic.title = unique_topic.title
    end
  end

  # validates_format_of

  test "#validates_format_of and no custom message" do
    expect_error_added(@topic, :title, :invalid, :default => nil, :value => '72x') do
      Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/
      @topic.title = '72x'
    end
  end

  test "#validates_format_of and a custom message" do
    expect_error_added(@topic, :title, :invalid, :default => 'custom', :value => '72x') do
      Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/, :message => 'custom'
      @topic.title = '72x'
    end
  end

  test "#validates_format_of finds the correct message translations" do
    assert_message_translations(@topic, :title, :invalid) do
      Topic.validates_format_of :title, :with => /^[1-9][0-9]*$/
      @topic.title = '72x'
    end
  end

  # validates_inclusion_of

  test "#validates_inclusion_of and no custom message" do
    list = %w(a b c)
    expect_error_added(@topic, :title, :inclusion, :default => nil, :value => 'z') do
      Topic.validates_inclusion_of :title, :in => list
      @topic.title = 'z'
    end
  end

  test "#validates_inclusion_of and a custom message" do
    list = %w(a b c)
    expect_error_added(@topic, :title, :inclusion, :default => 'custom', :value => 'z') do
      Topic.validates_inclusion_of :title, :in => list, :message => 'custom'
      @topic.title = 'z'
    end
  end

  test "#validates_inclusion_of finds the correct message translations" do
    list = %w(a b c)
    assert_message_translations(@topic, :title, :inclusion) do
      Topic.validates_inclusion_of :title, :in => list
      @topic.title = 'z'
    end
  end

  # validates_exclusion_of

  test "#validates_exclusion_of and no custom message" do
    list = %w(a b c)
    expect_error_added(@topic, :title, :exclusion, :default => nil, :value => 'a') do
      Topic.validates_exclusion_of :title, :in => list
      @topic.title = 'a'
    end
  end

  test "#validates_exclusion_of and a custom message" do
    list = %w(a b c)
    expect_error_added(@topic, :title, :exclusion, :default => 'custom', :value => 'a') do
      Topic.validates_exclusion_of :title, :in => list, :message => 'custom'
      @topic.title = 'a'
    end
  end

  test "#validates_exclusion_of finds the correct message translations" do
    list = %w(a b c)
    assert_message_translations(@topic, :title, :exclusion) do
      Topic.validates_exclusion_of :title, :in => list
      @topic.title = 'a'
    end
  end

  # validates_numericality_of :not_a_number, without :only_integer

  test "#validates_numericality_of (:not_a_number, w/o :only_integer) no custom message" do
    expect_error_added(@topic, :title, :not_a_number, :default => nil, :value => 'a') do
      Topic.validates_numericality_of :title
      @topic.title = 'a'
    end
  end

  test "#validates_numericality_of (:not_a_number, w/o :only_integer) and a custom message" do
    expect_error_added(@topic, :title, :not_a_number, :default => 'custom', :value => 'a') do
      Topic.validates_numericality_of :title, :message => 'custom'
      @topic.title = 'a'
    end
  end

  test "#validates_numericality_of (:not_a_number, w/o :only_integer) finds the correct message translations" do
    assert_message_translations(@topic, :title, :not_a_number) do
      Topic.validates_numericality_of :title
      @topic.title = 'a'
    end
  end

  # validates_numericality_of :not_a_number, with :only_integer

  test "#validates_numericality_of (:not_a_number, with :only_integer) no custom message" do
    expect_error_added(@topic, :title, :not_a_number, :default => nil, :value => 'a') do
      Topic.validates_numericality_of :title, :only_integer => true
      @topic.title = 'a'
    end
  end

  test "#validates_numericality_of (:not_a_number, with :only_integer) and a custom message" do
    expect_error_added(@topic, :title, :not_a_number, :default => 'custom', :value => 'a') do
      Topic.validates_numericality_of :title, :only_integer => true, :message => 'custom'
      @topic.title = 'a'
    end
  end

  test "#validates_numericality_of (:not_a_number, with :only_integer) finds the correct message translations" do
    assert_message_translations(@topic, :title, :not_a_number) do
      Topic.validates_numericality_of :title, :only_integer => true
      @topic.title = 'a'
    end
  end

  # validates_numericality_of :odd

  test "#validates_numericality_of (:odd) no custom message" do
    expect_error_added(@topic, :title, :odd, :default => nil, :value => 0) do
      Topic.validates_numericality_of :title, :only_integer => true, :odd => true
      @topic.title = 0
    end
  end

  test "#validates_numericality_of (:odd) and a custom message" do
    expect_error_added(@topic, :title, :odd, :default => 'custom', :value => 0) do
      Topic.validates_numericality_of :title, :only_integer => true, :odd => true, :message => 'custom'
      @topic.title = 0
    end
  end

  test "#validates_numericality_of (:odd) finds the correct message translations" do
    assert_message_translations(@topic, :title, :odd) do
      Topic.validates_numericality_of :title, :only_integer => true, :odd => true
      @topic.title = 0
    end
  end

  # validates_numericality_of :even

  test "#validates_numericality_of (:even) no custom message" do
    expect_error_added(@topic, :title, :even, :default => nil, :value => 1) do
      Topic.validates_numericality_of :title, :only_integer => true, :even => true
      @topic.title = 1
    end
  end

  test "#validates_numericality_of (:even) and a custom message" do
    expect_error_added(@topic, :title, :even, :default => 'custom', :value => 1) do
      Topic.validates_numericality_of :title, :only_integer => true, :even => true, :message => 'custom'
      @topic.title = 1
    end
  end

  test "#validates_numericality_of (:even) finds the correct message translations" do
    assert_message_translations(@topic, :title, :even) do
      Topic.validates_numericality_of :title, :only_integer => true, :even => true
      @topic.title = 1
    end
  end

  # validates_numericality_of :less_than

  test "#validates_numericality_of (:less_than) no custom message" do
    expect_error_added(@topic, :title, :less_than, :default => nil, :value => 1, :count => 0) do
      Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0
      @topic.title = 1
    end
  end

  test "#validates_numericality_of (:less_than) and a custom message" do
    expect_error_added(@topic, :title, :less_than, :default => 'custom', :value => 1, :count => 0) do
      Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0, :message => 'custom'
      @topic.title = 1
    end
  end

  test "#validates_numericality_of (:less_than) finds the correct message translations" do
    assert_message_translations(@topic, :title, :less_than) do
      Topic.validates_numericality_of :title, :only_integer => true, :less_than => 0
      @topic.title = 1
    end
  end

  # validates_associated

  test "#validates_associated no custom message" do
    expect_error_added(replied_topic, :replies, :invalid, :default => nil, :value => replied_topic.replies) do
      Topic.validates_associated :replies
    end
  end

  test "#validates_associated and a custom message" do
    expect_error_added(replied_topic, :replies, :invalid, :default => 'custom', :value => replied_topic.replies) do
      Topic.validates_associated :replies, :message => 'custom'
    end
  end

  test "#validates_associated finds the correct message translations" do
    assert_message_translations(replied_topic, :replies, :invalid) do
      Topic.validates_associated :replies
    end
  end
end


# ACTIVERECORD ERROR
#
# * test that it passes given interpolation arguments, the human model name and human attribute name
# * test that it looks messages up with the the correct keys
# * test that it looks up the correct default messages

class ActiveRecordErrorI18nTests < ActiveSupport::TestCase
  include ActiveRecordValidationsI18nTestHelper

  def setup
    @reply = Reply.new
    @old_backend, I18n.backend = I18n.backend, I18n::Backend::Simple.new
  end

  def teardown
    I18n.backend = @old_backend
    I18n.locale = nil
  end

  def assert_error_message(message, *args)
    assert_equal message, ActiveRecord::Error.new(@reply, *args).message
  end

  def assert_full_message(message, *args)
    assert_equal message, ActiveRecord::Error.new(@reply, *args).full_message
  end

  test ":default is only given to message if a symbol is supplied" do
    store_translations(:errors => { :messages => { :"foo bar" => "You fooed: %{value}." } })
    @reply.errors.add(:title, :inexistent, :default => "foo bar")
    assert_equal "foo bar", @reply.errors[:title]
  end

  test "#generate_message passes the model attribute value for interpolation" do
    store_translations(:errors => { :messages => { :foo => "You fooed: %{value}." } })
    @reply.title = "da title"
    assert_error_message 'You fooed: da title.', :title, :foo
  end

  test "#generate_message passes the human_name of the model for interpolation" do
    store_translations(
      :errors => { :messages => { :foo => "You fooed: %{model}." } },
      :models => { :topic => 'da topic' }
    )
    assert_error_message 'You fooed: da topic.', :title, :foo
  end

  test "#generate_message passes the human_name of the attribute for interpolation" do
    store_translations(
      :errors => { :messages => { :foo => "You fooed: %{attribute}." } },
      :attributes => { :topic => { :title => 'da topic title' } }
    )
    assert_error_message 'You fooed: da topic title.', :title, :foo
  end

  # generate_message will look up the key for the error message (e.g. :blank) in these namespaces:
  #
  #   activerecord.errors.models.reply.attributes.title
  #   activerecord.errors.models.reply
  #   activerecord.errors.models.topic.attributes.title
  #   activerecord.errors.models.topic
  #   [default from class level :validates_foo statement if this is a String]
  #   activerecord.errors.messages

  test "#generate_message key fallbacks (given a String as key)" do
    store_translations(
      :errors => {
        :models => {
          :reply => {
            :attributes => { :title => { :custom => 'activerecord.errors.models.reply.attributes.title.custom' } },
            :custom => 'activerecord.errors.models.reply.custom'
          },
          :topic => {
            :attributes => { :title => { :custom => 'activerecord.errors.models.topic.attributes.title.custom' } },
            :custom => 'activerecord.errors.models.topic.custom'
          }
        },
        :messages => {
          :custom => 'activerecord.errors.messages.custom',
          :kaputt => 'activerecord.errors.messages.kaputt'
        }
      }
    )

    assert_error_message 'activerecord.errors.models.reply.attributes.title.custom', :title, :kaputt, :message => 'custom'
    delete_translation  :'activerecord.errors.models.reply.attributes.title.custom'

    assert_error_message 'activerecord.errors.models.reply.custom', :title, :kaputt, :message => 'custom'
    delete_translation  :'activerecord.errors.models.reply.custom'

    assert_error_message 'activerecord.errors.models.topic.attributes.title.custom', :title, :kaputt, :message => 'custom'
    delete_translation  :'activerecord.errors.models.topic.attributes.title.custom'

    assert_error_message 'activerecord.errors.models.topic.custom', :title, :kaputt, :message => 'custom'
    delete_translation  :'activerecord.errors.models.topic.custom'

    assert_error_message 'activerecord.errors.messages.custom', :title, :kaputt, :message => 'custom'
    delete_translation  :'activerecord.errors.messages.custom'

    # Implementing this would clash with the AR default behaviour of using validates_foo :message => 'foo'
    # as an untranslated string. I.e. at this point we can either fall back to the given string from the
    # class-level macro (validates_*) or fall back to the default message for this validation type.
    # assert_error_message 'activerecord.errors.messages.kaputt', :title, :kaputt, :message => 'custom'

    assert_error_message 'custom', :title, :kaputt, :message => 'custom'
  end

  test "#generate_message key fallbacks (given a Symbol as key)" do
    store_translations(
      :errors => {
        :models => {
          :reply => {
            :attributes => { :title => { :kaputt => 'activerecord.errors.models.reply.attributes.title.kaputt' } },
            :kaputt => 'activerecord.errors.models.reply.kaputt'
          },
          :topic => {
            :attributes => { :title => { :kaputt => 'activerecord.errors.models.topic.attributes.title.kaputt' } },
            :kaputt => 'activerecord.errors.models.topic.kaputt'
          }
        },
        :messages => {
          :kaputt => 'activerecord.errors.messages.kaputt'
        }
      }
    )

    assert_error_message 'activerecord.errors.models.reply.attributes.title.kaputt', :title, :kaputt
    delete_translation  :'activerecord.errors.models.reply.attributes.title.kaputt'

    assert_error_message 'activerecord.errors.models.reply.kaputt', :title, :kaputt
    delete_translation  :'activerecord.errors.models.reply.kaputt'

    assert_error_message 'activerecord.errors.models.topic.attributes.title.kaputt', :title, :kaputt
    delete_translation  :'activerecord.errors.models.topic.attributes.title.kaputt'

    assert_error_message 'activerecord.errors.models.topic.kaputt', :title, :kaputt
    delete_translation  :'activerecord.errors.models.topic.kaputt'

    assert_error_message 'activerecord.errors.messages.kaputt', :title, :kaputt
  end

  # full_messages

  test "#full_message with no format present" do
    store_translations(:errors => { :messages => { :kaputt => 'is kaputt' } })
    assert_full_message 'Title is kaputt', :title, :kaputt
  end

  test "#full_message with a format present" do
    store_translations(:errors => { :messages => { :kaputt => 'is kaputt' }, :full_messages => { :format => '%{attribute}: %{message}' } })
    assert_full_message 'Title: is kaputt', :title, :kaputt
  end

  test "#full_message with a type specific format present" do
    store_translations(:errors => { :messages => { :kaputt => 'is kaputt' }, :full_messages => { :kaputt => '%{attribute} %{message}!' } })
    assert_full_message 'Title is kaputt!', :title, :kaputt
  end

  test "#full_message with class-level specified custom message" do
    store_translations(:errors => { :messages => { :broken => 'is kaputt' }, :full_messages => { :broken => '%{attribute} %{message}?!' } })
    assert_full_message 'Title is kaputt?!', :title, :kaputt, :message => :broken
  end

  test "#full_message with different scope" do
    store_translations(:my_errors => { :messages => { :kaputt => 'is kaputt' } })
    assert_full_message 'Title is kaputt', :title, :kaputt, :scope => [:activerecord, :my_errors]

    store_translations(:my_errors => { :full_messages => { :kaputt => '%{attribute} %{message}!' } })
    assert_full_message 'Title is kaputt!', :title, :kaputt, :scope => [:activerecord, :my_errors]
  end

  # switch locales

  test "#message allows to switch locales" do
    store_translations(:en, :errors => { :messages => { :kaputt => 'is kaputt' } })
    store_translations(:de, :errors => { :messages => { :kaputt => 'ist kaputt' } })

    assert_error_message 'is kaputt', :title, :kaputt
    I18n.locale = :de
    assert_error_message 'ist kaputt', :title, :kaputt
    I18n.locale = :en
    assert_error_message 'is kaputt', :title, :kaputt
  end

  test "#full_message allows to switch locales" do
    store_translations(:en, :errors => { :messages => { :kaputt => 'is kaputt' } }, :attributes => { :topic => { :title => 'The title' } })
    store_translations(:de, :errors => { :messages => { :kaputt => 'ist kaputt' } }, :attributes => { :topic => { :title => 'Der Titel' } })

    assert_full_message 'The title is kaputt', :title, :kaputt
    I18n.locale = :de
    assert_full_message 'Der Titel ist kaputt', :title, :kaputt
    I18n.locale = :en
    assert_full_message 'The title is kaputt', :title, :kaputt
  end
end

# ACTIVERECORD DEFAULT ERROR MESSAGES
#
# * test that Error generates the default error messages

class ActiveRecordDefaultErrorMessagesI18nTests < ActiveSupport::TestCase
  def assert_default_error_message(message, *args)
    assert_equal message, error_message(*args)
  end

  def error_message(*args)
    ActiveRecord::Error.new(Topic.new, :title, *args).message
  end

  # used by: validates_inclusion_of
  test "default error message: inclusion" do
    assert_default_error_message 'is not included in the list', :inclusion, :value => 'title'
  end

  # used by: validates_exclusion_of
  test "default error message: exclusion" do
    assert_default_error_message 'is reserved', :exclusion, :value => 'title'
  end

  # used by: validates_associated and validates_format_of
  test "default error message: invalid" do
    assert_default_error_message 'is invalid', :invalid, :value => 'title'
  end

  # used by: validates_confirmation_of
  test "default error message: confirmation" do
    assert_default_error_message "doesn't match confirmation", :confirmation, :default => nil
  end

  # used by: validates_acceptance_of
  test "default error message: accepted" do
    assert_default_error_message "must be accepted", :accepted
  end

  # used by: add_on_empty
  test "default error message: empty" do
    assert_default_error_message "can't be empty", :empty
  end

  # used by: add_on_blank
  test "default error message: blank" do
    assert_default_error_message "can't be blank", :blank
  end

  # used by: validates_length_of
  test "default error message: too_long" do
    assert_default_error_message "is too long (maximum is 10 characters)", :too_long, :count => 10
  end

  # used by: validates_length_of
  test "default error message: too_short" do
    assert_default_error_message "is too short (minimum is 10 characters)", :too_short, :count => 10
  end

  # used by: validates_length_of
  test "default error message: wrong_length" do
    assert_default_error_message "is the wrong length (should be 10 characters)", :wrong_length, :count => 10
  end

  # used by: validates_uniqueness_of
  test "default error message: taken" do
    assert_default_error_message "has already been taken", :taken, :value => 'title'
  end

  # used by: validates_numericality_of
  test "default error message: not_a_number" do
    assert_default_error_message "is not a number", :not_a_number, :value => 'title'
  end

  # used by: validates_numericality_of
  test "default error message: greater_than" do
    assert_default_error_message "must be greater than 10", :greater_than, :value => 'title', :count => 10
  end

  # used by: validates_numericality_of
  test "default error message: greater_than_or_equal_to" do
    assert_default_error_message "must be greater than or equal to 10", :greater_than_or_equal_to, :value => 'title', :count => 10
  end

  # used by: validates_numericality_of
  test "default error message: equal_to" do
    assert_default_error_message "must be equal to 10", :equal_to, :value => 'title', :count => 10
  end

  # used by: validates_numericality_of
  test "default error message: less_than" do
    assert_default_error_message "must be less than 10", :less_than, :value => 'title', :count => 10
  end

  # used by: validates_numericality_of
  test "default error message: less_than_or_equal_to" do
    assert_default_error_message "must be less than or equal to 10", :less_than_or_equal_to, :value => 'title', :count => 10
  end

  # used by: validates_numericality_of
  test "default error message: odd" do
    assert_default_error_message "must be odd", :odd, :value => 'title', :count => 10
  end

  # used by: validates_numericality_of
  test "default error message: even" do
    assert_default_error_message "must be even", :even, :value => 'title', :count => 10
  end

  test "custom message string interpolation" do
    assert_equal 'custom message title', error_message(:invalid, :default => 'custom message %{value}', :value => 'title')
  end
end

# ACTIVERECORD VALIDATION ERROR MESSAGES - FULL STACK
#
# * test a few combinations full stack to ensure the tests above are correct

class I18nPerson < Person
end

class ActiveRecordValidationsI18nFullStackTests < ActiveSupport::TestCase
  include ActiveRecordValidationsI18nTestHelper

  def setup
    reset_callbacks(I18nPerson)
    @old_backend, I18n.backend = I18n.backend, I18n::Backend::Simple.new
    @person = I18nPerson.new
  end

  def teardown
    reset_callbacks(I18nPerson)
    I18n.backend = @old_backend
  end

  def assert_name_invalid(message)
    yield
    @person.valid?
    assert_equal message, @person.errors.on(:name)
  end

  # Symbols as class-level validation messages

  test "Symbol as class level validation message translated per attribute (translation on child class)" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:models => {:i18n_person => {:attributes => {:name => {:broken => "is broken"}}}}}
      I18nPerson.validates_presence_of :name, :message => :broken
    end
  end

  test "Symbol as class level validation message translated per attribute (translation on base class)" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:models => {:person => {:attributes => {:name => {:broken => "is broken"}}}}}
      I18nPerson.validates_presence_of :name, :message => :broken
    end
  end

  test "Symbol as class level validation message translated per model (translation on child class)" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:models => {:i18n_person => {:broken => "is broken"}}}
      I18nPerson.validates_presence_of :name, :message => :broken
    end
  end

  test "Symbol as class level validation message translated per model (translation on base class)" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:models => {:person => {:broken => "is broken"}}}
      I18nPerson.validates_presence_of :name, :message => :broken
    end
  end

  test "Symbol as class level validation message translated as error message" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:messages => {:broken => "is broken"}}
      I18nPerson.validates_presence_of :name, :message => :broken
    end
  end

  # Strings as class-level validation messages

  test "String as class level validation message translated per attribute (translation on child class)" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:models => {:i18n_person => {:attributes => {:name => {"is broken" => "is broken"}}}}}
      I18nPerson.validates_presence_of :name, :message => "is broken"
    end
  end

  test "String as class level validation message translated per attribute (translation on base class)" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:models => {:person => {:attributes => {:name => {"is broken" => "is broken"}}}}}
      I18nPerson.validates_presence_of :name, :message => "is broken"
    end
  end

  test "String as class level validation message translated per model (translation on child class)" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:models => {:i18n_person => {"is broken" => "is broken"}}}
      I18nPerson.validates_presence_of :name, :message => "is broken"
    end
  end

  test "String as class level validation message translated per model (translation on base class)" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:models => {:person => {"is broken" => "is broken"}}}
      I18nPerson.validates_presence_of :name, :message => "is broken"
    end
  end

  test "String as class level validation message translated as error message" do
    assert_name_invalid("is broken") do
      store_translations :errors => {:messages => {"is broken" => "is broken"}}
      I18nPerson.validates_presence_of :name, :message => "is broken"
    end
  end

  test "String as class level validation message not translated (uses message as default)" do
    assert_name_invalid("is broken!") do
      I18nPerson.validates_presence_of :name, :message => "is broken!"
    end
  end
end

class ActiveRecordValidationsI18nFullMessagesFullStackTests < ActiveSupport::TestCase
  include ActiveRecordValidationsI18nTestHelper

  def setup
    reset_callbacks(I18nPerson)
    @old_backend, I18n.backend = I18n.backend, I18n::Backend::Simple.new
    @person = I18nPerson.new
  end

  def teardown
    reset_callbacks(I18nPerson)
    I18n.backend = @old_backend
  end

  def assert_full_message(message)
    yield
    @person.valid?
    assert_equal message, @person.errors.full_messages.join
  end

  test "full_message format stored per custom error message key" do
    assert_full_message("Name is broken!") do
      store_translations :errors => { :messages => { :broken => 'is broken' }, :full_messages => { :broken => '%{attribute} %{message}!' } }
      I18nPerson.validates_presence_of :name, :message => :broken
    end
  end

  test "full_message format stored per error type" do
    assert_full_message("Name can't be blank!") do
      store_translations :errors => { :full_messages => { :blank => '%{attribute} %{message}!' } }
      I18nPerson.validates_presence_of :name
    end
  end
  # ActiveRecord#RecordInvalid exception

  test "full_message format stored as default" do
    assert_full_message("Name: can't be blank") do
      store_translations :errors => { :full_messages => { :format => '%{attribute}: %{message}' } }
      I18nPerson.validates_presence_of :name
    end
  end
  test "RecordInvalid exception can be localized" do
    topic = Topic.new
    topic.errors.add(:title, :invalid)
    topic.errors.add(:title, :blank)
    assert_equal "Validation failed: Title is invalid, Title can't be blank", ActiveRecord::RecordInvalid.new(topic).message
  end
end
