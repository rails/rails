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
    assert t.valid?

    t.title_confirmation = 'Parallel Lives'
    assert t.invalid?

    t.title_confirmation = nil
    t.title = 'Parallel Lives'
    assert t.valid?

    t.title_confirmation = 'Parallel Lives'
    assert t.valid?
  end

  def test_title_confirmation
    Topic.validates_confirmation_of(:title)

    t = Topic.new(title: 'We should be confirmed', title_confirmation: '')
    assert t.invalid?

    t.title_confirmation = 'We should be confirmed'
    assert t.valid?
  end

  def test_validates_confirmation_of_for_ruby_class
    Person.validates_confirmation_of :karma

    p = Person.new
    p.karma_confirmation = 'None'
    assert p.invalid?

    assert_equal ["doesn't match Karma"], p.errors[:karma]

    p.karma = 'None'
    assert p.valid?
  ensure
    Person.clear_validators!
  end

  def test_title_confirmation_with_i18n_attribute
    begin
      @old_load_path, @old_backend = I18n.load_path.dup, I18n.backend
      I18n.load_path.clear
      I18n.backend = I18n::Backend::Simple.new
      I18n.backend.store_translations('en', {
        errors: { messages: { confirmation: "doesn't match %{attribute}" } },
        activemodel: { attributes: { topic: { title: 'Test Title'} } }
      })

      Topic.validates_confirmation_of(:title)

      t = Topic.new(title: 'We should be confirmed', title_confirmation: '')
      assert t.invalid?
      assert_equal ["doesn't match Test Title"], t.errors[:title]
    ensure
      I18n.load_path.replace @old_load_path
      I18n.backend = @old_backend
      I18n.backend.reload!
    end
  end

  def test_error_is_attached_to_attribute_itself_and_not_its_confirmation_twin
    Topic.validates_confirmation_of(:title)
    t = Topic.new(title: 'Sometitle', title_confirmation: 'NotThatTitle')
    assert t.invalid?
    assert_not_empty t.errors[:title]
    assert_empty t.errors[:title_confirmation]
  end

  def test_does_not_override_confirmation_reader_if_present
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

  def test_does_not_override_confirmation_writer_if_present
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
end
