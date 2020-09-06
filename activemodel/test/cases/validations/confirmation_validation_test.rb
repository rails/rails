# frozen_string_literal: true

require 'cases/helper'

require 'models/topic'
require 'models/person'

class ConfirmationValidationTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  def test_no_title_confirmation
    Topic.validates_confirmation_of(:title)

    t = Topic.new(author_name: 'Plutarch')
    assert_predicate t, :valid?

    t.title_confirmation = 'Parallel Lives'
    assert_predicate t, :invalid?

    t.title_confirmation = nil
    t.title = 'Parallel Lives'
    assert_predicate t, :valid?

    t.title_confirmation = 'Parallel Lives'
    assert_predicate t, :valid?
  end

  def test_title_confirmation
    Topic.validates_confirmation_of(:title)

    t = Topic.new('title' => 'We should be confirmed', 'title_confirmation' => '')
    assert_predicate t, :invalid?

    t.title_confirmation = 'We should be confirmed'
    assert_predicate t, :valid?
  end

  def test_validates_confirmation_of_with_boolean_attribute
    Topic.validates_confirmation_of(:approved)

    t = Topic.new(approved: true, approved_confirmation: nil)
    assert_predicate t, :valid?

    t.approved_confirmation = false
    assert_predicate t, :invalid?

    t.approved_confirmation = true
    assert_predicate t, :valid?
  end

  def test_validates_confirmation_of_for_ruby_class
    Person.validates_confirmation_of :karma

    p = Person.new
    p.karma_confirmation = 'None'
    assert_predicate p, :invalid?

    assert_equal ["doesn't match Karma"], p.errors[:karma_confirmation]

    p.karma = 'None'
    assert_predicate p, :valid?
  ensure
    Person.clear_validators!
  end

  def test_title_confirmation_with_i18n_attribute
    @old_load_path, @old_backend = I18n.load_path.dup, I18n.backend
    I18n.load_path.clear
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations('en',
      errors: { messages: { confirmation: "doesn't match %{attribute}" } },
      activemodel: { attributes: { topic: { title: 'Test Title' } } })

    Topic.validates_confirmation_of(:title)

    t = Topic.new('title' => 'We should be confirmed', 'title_confirmation' => '')
    assert_predicate t, :invalid?
    assert_equal ["doesn't match Test Title"], t.errors[:title_confirmation]
  ensure
    I18n.load_path.replace @old_load_path
    I18n.backend = @old_backend
    I18n.backend.reload!
  end

  test 'does not override confirmation reader if present' do
    klass = Class.new do
      include ActiveModel::Validations

      def title_confirmation
        'expected title'
      end

      validates_confirmation_of :title
    end

    assert_equal 'expected title', klass.new.title_confirmation,
     'confirmation validation should not override the reader'
  end

  test 'does not override confirmation writer if present' do
    klass = Class.new do
      include ActiveModel::Validations

      def title_confirmation=(value)
        @title_confirmation = 'expected title'
      end

      validates_confirmation_of :title
    end

    model = klass.new
    model.title_confirmation = 'new title'
    assert_equal 'expected title', model.title_confirmation,
     'confirmation validation should not override the writer'
  end

  def test_title_confirmation_with_case_sensitive_option_true
    Topic.validates_confirmation_of(:title, case_sensitive: true)

    t = Topic.new(title: 'title', title_confirmation: 'Title')
    assert_predicate t, :invalid?
  end

  def test_title_confirmation_with_case_sensitive_option_false
    Topic.validates_confirmation_of(:title, case_sensitive: false)

    t = Topic.new(title: 'title', title_confirmation: 'Title')
    assert_predicate t, :valid?
  end
end
