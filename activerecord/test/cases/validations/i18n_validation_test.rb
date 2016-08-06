require "cases/helper"
require "models/topic"
require "models/reply"

class I18nValidationTest < ActiveRecord::TestCase
  repair_validations(Topic, Reply)

  def setup
    repair_validations(Topic, Reply)
    Reply.validates_presence_of(:title)
    @topic = Topic.new
    @old_load_path, @old_backend = I18n.load_path.dup, I18n.backend
    I18n.load_path.clear
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations("en", :errors => {:messages => {:custom => nil}})
  end

  teardown do
    I18n.load_path.replace @old_load_path
    I18n.backend = @old_backend
  end

  def unique_topic
    @unique ||= Topic.create :title => "unique!"
  end

  def replied_topic
    @replied_topic ||= begin
      topic = Topic.create(:title => "topic")
      topic.replies << Reply.new
      topic
    end
  end

  # A set of common cases for ActiveModel::Validations message generation that
  # are used to generate tests to keep things DRY
  #
  COMMON_CASES = [
  # [ case,                                validation_options,            generate_message_options]
    [ "given no options",                  {},                            {}],
    [ "given custom message",              {:message => "custom"},        {:message => "custom"}],
    [ "given if condition",                {:if     => lambda { true }},  {}],
    [ "given unless condition",            {:unless => lambda { false }}, {}],
    [ "given option that is not reserved", {:format => "jpg"},            {:format => "jpg" }],
    [ "given on condition",                {on: [:create, :update] },     {}]
  ]

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_uniqueness_of on generated message #{name}" do
      Topic.validates_uniqueness_of :title, validation_options
      @topic.title = unique_topic.title
      assert_called_with(@topic.errors, :generate_message, [:title, :taken, generate_message_options.merge(:value => "unique!")]) do
        @topic.valid?
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_associated on generated message #{name}" do
      Topic.validates_associated :replies, validation_options
      assert_called_with(replied_topic.errors, :generate_message, [:replies, :invalid, generate_message_options.merge(:value => replied_topic.replies)]) do
        replied_topic.save
      end
    end
  end

  def test_validates_associated_finds_custom_model_key_translation
    I18n.backend.store_translations "en", :activerecord => {:errors => {:models => {:topic => {:attributes => {:replies => {:invalid => "custom message"}}}}}}
    I18n.backend.store_translations "en", :activerecord => {:errors => {:messages => {:invalid => "global message"}}}

    Topic.validates_associated :replies
    replied_topic.valid?
    assert_equal ["custom message"], replied_topic.errors[:replies].uniq
  end

  def test_validates_associated_finds_global_default_translation
    I18n.backend.store_translations "en", :activerecord => {:errors => {:messages => {:invalid => "global message"}}}

    Topic.validates_associated :replies
    replied_topic.valid?
    assert_equal ["global message"], replied_topic.errors[:replies]
  end

end
