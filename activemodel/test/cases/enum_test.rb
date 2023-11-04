# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/book"
require "active_support/log_subscriber/test_helper"

class EnumTest < ActiveModel::TestCase
  setup do
    @book = Book.new(
      status: :published,
      last_read: :read,
      language: :english,
      author_visibility: :visible,
      illustrator_visibility: :visible,
      font_size: :medium,
      difficulty: :medium,
      boolean_status: :enabled,
      cover: "soft"
    )
    @book.changes_applied
  end

  test "type.cast" do
    type = Book.type_for_attribute(:status)

    assert_equal "proposed",  type.cast(0)
    assert_equal "written",   type.cast(1)
    assert_equal "published", type.cast(2)

    assert_equal "proposed",  type.cast(:proposed)
    assert_equal "written",   type.cast(:written)
    assert_equal "published", type.cast(:published)

    assert_equal "proposed",  type.cast("proposed")
    assert_equal "written",   type.cast("written")
    assert_equal "published", type.cast("published")

    assert_equal :unknown,    type.cast(:unknown)
    assert_equal "unknown",   type.cast("unknown")
  end

  test "type.serialize" do
    type = Book.type_for_attribute(:status)

    assert_equal 0, type.serialize(0)
    assert_equal 1, type.serialize(1)
    assert_equal 2, type.serialize(2)

    assert_equal 0, type.serialize(:proposed)
    assert_equal 1, type.serialize(:written)
    assert_equal 2, type.serialize(:published)

    assert_equal 0, type.serialize("proposed")
    assert_equal 1, type.serialize("written")
    assert_equal 2, type.serialize("published")

    assert_nil type.serialize(:unknown)
    assert_nil type.serialize("unknown")
  end

  test "query state by predicate" do
    assert_predicate @book, :published?
    assert_not_predicate @book, :written?
    assert_not_predicate @book, :proposed?

    assert_predicate @book, :read?
    assert_predicate @book, :in_english?
    assert_predicate @book, :author_visibility_visible?
    assert_predicate @book, :illustrator_visibility_visible?
    assert_predicate @book, :with_medium_font_size?
    assert_predicate @book, :medium_to_read?
  end

  test "query state with strings" do
    assert_equal "published", @book.status
    assert_equal "read", @book.last_read
    assert_equal "english", @book.language
    assert_equal "visible", @book.author_visibility
    assert_equal "visible", @book.illustrator_visibility
    assert_equal "medium", @book.difficulty
    assert_equal "soft", @book.cover
  end

  test "update by declaration" do
    @book.written!
    assert_predicate @book, :written?
    @book.in_english!
    assert_predicate @book, :in_english?
    @book.author_visibility_visible!
    assert_predicate @book, :author_visibility_visible?
    @book.hard!
    assert_predicate @book, :hard?
  end

  test "enum methods are overwritable" do
    assert_equal "do publish work...", @book.published!
    assert_predicate @book, :published?
  end

  test "direct assignment" do
    @book.status = :written
    assert_predicate @book, :written?
    @book.cover = :hard
    assert_predicate @book, :hard?
  end

  test "assign string value" do
    @book.status = "written"
    assert_predicate @book, :written?
    @book.cover = "hard"
    assert_predicate @book, :hard?
  end

  test "enum changed attributes" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :spanish
    assert_equal old_status, @book.changed_attributes[:status]
    assert_equal old_language, @book.changed_attributes[:language]
  end

  test "enum value after write symbol" do
    @book.status = :proposed
    assert_equal "proposed", @book.status
  end

  test "enum value after write string" do
    @book.status = "proposed"
    assert_equal "proposed", @book.status
  end

  test "enum changes" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :spanish
    assert_equal [old_status, "proposed"], @book.changes[:status]
    assert_equal [old_language, "spanish"], @book.changes[:language]
  end

  test "enum attribute was" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :published
    @book.language = :spanish
    assert_equal old_status, @book.attribute_was(:status)
    assert_equal old_language, @book.attribute_was(:language)
  end

  test "enum attribute changed" do
    @book.status = :proposed
    @book.language = :french
    assert @book.attribute_changed?(:status)
    assert @book.attribute_changed?(:language)
  end

  test "enum attribute changed to" do
    @book.status = :proposed
    @book.language = :french
    assert @book.attribute_changed?(:status, to: "proposed")
    assert @book.attribute_changed?(:language, to: "french")
  end

  test "enum attribute changed from" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :french
    assert @book.attribute_changed?(:status, from: old_status)
    assert @book.attribute_changed?(:language, from: old_language)
  end

  test "enum attribute changed from old status to new status" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :french
    assert @book.attribute_changed?(:status, from: old_status, to: "proposed")
    assert @book.attribute_changed?(:language, from: old_language, to: "french")
  end

  test "enum didn't change" do
    old_status = @book.status
    @book.status = old_status
    assert_not @book.attribute_changed?(:status)
  end

  test "persist changes that are dirty" do
    @book.status = :proposed
    assert @book.attribute_changed?(:status)
    @book.status = :written
    assert @book.attribute_changed?(:status)
  end

  test "reverted changes that are not dirty" do
    old_status = @book.status
    @book.status = :proposed
    assert @book.attribute_changed?(:status)
    @book.status = old_status
    assert_not @book.attribute_changed?(:status)
  end

  test "reverted changes are not dirty going from nil to value and back" do
    book = Book.new(nullable_status: nil)

    book.nullable_status = :married
    assert book.attribute_changed?(:nullable_status)

    book.nullable_status = nil
    assert_not book.attribute_changed?(:nullable_status)
  end

  test "assign non existing value raises an error" do
    e = assert_raises(ArgumentError) do
      @book.status = :unknown
    end
    assert_equal "'unknown' is not a valid status", e.message
  end

  test "validation with 'validate: true' option" do
    klass = Class.new do
      def self.name; "Book"; end
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations
      include ActiveModel::Enum
      attribute :status, :integer
      enum :status, [:proposed, :written], validate: true
    end

    valid_book = klass.new(status: "proposed")
    assert_predicate valid_book, :valid?

    valid_book = klass.new(status: "written")
    assert_predicate valid_book, :valid?

    invalid_book = klass.new(status: nil)
    assert_not_predicate invalid_book, :valid?

    invalid_book = klass.new(status: "unknown")
    assert_not_predicate invalid_book, :valid?
  end

  test "validation with 'validate: hash' option" do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations
      include ActiveModel::Enum
      attribute :status, :integer
      def self.name; "Book"; end
      enum :status, [:proposed, :written], validate: { allow_nil: true }
    end

    valid_book = klass.new(status: "proposed")
    assert_predicate valid_book, :valid?

    valid_book = klass.new(status: "written")
    assert_predicate valid_book, :valid?

    valid_book = klass.new(status: nil)
    assert_predicate valid_book, :valid?

    invalid_book = klass.new(status: "unknown")
    assert_not_predicate invalid_book, :valid?
  end

  test "assign nil value" do
    @book.status = nil
    assert_nil @book.status
  end

  test "assign nil value to enum which defines nil value to hash" do
    @book.last_read = nil
    assert_equal "forgotten", @book.last_read
  end

  test "assign empty string value" do
    @book.status = ""
    assert_nil @book.status
  end

  test "assign false value to a field defined as not boolean" do
    @book.status = false
    assert_nil @book.status
  end

  test "assign false value to a field defined as boolean" do
    @book.boolean_status = false
    assert_equal "disabled", @book.boolean_status
  end

  test "assign long empty string value" do
    @book.status = "   "
    assert_nil @book.status
  end

  test "constant to access the mapping" do
    assert_equal 0, Book.statuses[:proposed]
    assert_equal 1, Book.statuses["written"]
    assert_equal 2, Book.statuses[:published]
  end

  test "attribute_before_type_cast" do
    assert_equal 2, @book.status_before_type_cast
    assert_equal "published", @book.status

    @book.status = "published"

    assert_equal "published", @book.status_before_type_cast
    assert_equal "published", @book.status
  end

  test "attribute_for_database" do
    assert_equal 2, @book.status_for_database
    assert_equal "published", @book.status

    @book.status = "published"

    assert_equal 2, @book.status_for_database
    assert_equal "published", @book.status
  end

  test "attributes_for_database" do
    assert_equal 2, @book.attributes_for_database["status"]

    @book.status = "published"

    assert_equal 2, @book.attributes_for_database["status"]
  end

  test "invalid definition values raise an ArgumentError" do
    e = assert_raises(ArgumentError) do
      Class.new do
        include ActiveModel::Attributes
        include ActiveModel::Enum
        attribute :status, :integer
        enum :status
      end
    end

    assert_match(/must not be empty\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new do
        include ActiveModel::Attributes
        include ActiveModel::Enum
        attribute :status, :integer
        enum(:status, {}, **{})
      end
    end

    assert_match(/must not be empty\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new do
        include ActiveModel::Attributes
        include ActiveModel::Enum
        attribute :status, :integer
        enum :status, []
      end
    end

    assert_match(/must not be empty\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new do
        include ActiveModel::Attributes
        include ActiveModel::Enum
        attribute :status, :integer
        enum status: [proposed: 1, written: 2, published: 3]
      end
    end

    assert_match(/must only contain symbols or strings\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new do
        include ActiveModel::Attributes
        include ActiveModel::Enum
        attribute :status, :integer
        enum status: { "" => 1, "active" => 2 }
      end
    end

    assert_match(/must not contain a blank name\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new do
        include ActiveModel::Attributes
        include ActiveModel::Enum
        attribute :status, :integer
        enum status: ["active", ""]
      end
    end

    assert_match(/must not contain a blank name\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new do
        include ActiveModel::Attributes
        include ActiveModel::Enum
        attribute :status, :integer
        enum status: Object.new
      end
    end

    assert_match(/must be either a non-empty hash or an array\.$/, e.message)
  end

  test "can use id as a value with a prefix or suffix" do
    assert_nothing_raised do
      Class.new do
        include ActiveModel::Attributes
        include ActiveModel::Enum
        attribute :status, :integer
        enum status_1: [:id], _prefix: true
        enum status_2: [:id], _suffix: true
      end
    end
  end

  test "overriding enum method should not raise" do
    assert_nothing_raised do
      Class.new do
        include ActiveModel::Attributes
        include ActiveModel::Enum
        attribute :status, :integer

        def published!
          super
          "do publish work..."
        end

        enum status: [:proposed, :written, :published]

        def written!
          super
          "do written work..."
        end
      end
    end
  end

  test "validate inclusion of value in array" do
    klass = Class.new do
      def self.name; "Book"; end
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations
      include ActiveModel::Enum
      attribute :status, :integer
      enum status: [:proposed, :written]
      validates_inclusion_of :status, in: ["written"]
    end
    invalid_book = klass.new(status: "proposed")
    assert_not_predicate invalid_book, :valid?
    valid_book = klass.new(status: "written")
    assert_predicate valid_book, :valid?
  end

  test "enums are distinct per class" do
    klass1 = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Dirty
      include ActiveModel::Enum
      attribute :status, :integer
      enum status: [:proposed, :written]
    end

    klass2 = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Dirty
      include ActiveModel::Enum
      attribute :status, :integer
      enum status: [:drafted, :uploaded]
    end

    book1 = klass1.new(status: "proposed")
    book1.changes_applied
    book1.status = :written
    assert_equal ["proposed", "written"], book1.status_change

    book2 = klass2.new(status: "drafted")
    book2.changes_applied
    book2.status = :uploaded
    assert_equal ["drafted", "uploaded"], book2.status_change
  end

  test "enums are inheritable" do
    subklass1 = Class.new(Book)

    subklass2 = Class.new(Book) do
      enum status: [:drafted, :uploaded]
    end

    book1 = subklass1.new(status: "proposed")
    book1.changes_applied
    book1.status = :written
    assert_equal ["proposed", "written"], book1.status_change

    book2 = subklass2.new(status: "drafted")
    book2.changes_applied
    book2.status = :uploaded
    assert_equal ["drafted", "uploaded"], book2.status_change
  end

  test "attempting to modify enum raises error" do
    e = assert_raises(RuntimeError) do
      Book.statuses["bad_enum"] = 40
    end

    assert_match(/can't modify frozen/, e.message)

    e = assert_raises(RuntimeError) do
      Book.statuses.delete("published")
    end

    assert_match(/can't modify frozen/, e.message)
  end

  test "declare multiple enums at a time" do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      attribute :nullable_status, :integer
      enum status: [:proposed, :written, :published],
           nullable_status: [:single, :married]
    end

    book1 = klass.new(status: :proposed)
    assert_predicate book1, :proposed?

    book2 = klass.new(nullable_status: :single)
    assert_predicate book2, :single?
  end

  test "declare multiple enums with { _prefix: true }" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      attribute :last_read, :integer

      enum(
        status: [:value_1],
        last_read: [:value_1],
        _prefix: true
      )
    end

    instance = klass.new
    assert_respond_to instance, :status_value_1?
    assert_respond_to instance, :last_read_value_1?
  end

  test "declare multiple enums with { _suffix: true }" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      attribute :last_read, :integer

      enum(
        status: [:value_1],
        last_read: [:value_1],
        _suffix: true
      )
    end

    instance = klass.new
    assert_respond_to instance, :value_1_status?
    assert_respond_to instance, :value_1_last_read?
  end

  test "enum with alias_attribute" do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      alias_attribute :aliased_status, :status
      enum aliased_status: [:proposed, :written, :published]
    end

    book = klass.new(status: "proposed")
    assert_predicate book, :proposed?
    assert_equal "proposed", book.aliased_status
  end

  test "query state by predicate with prefix" do
    assert_predicate @book, :author_visibility_visible?
    assert_not_predicate @book, :author_visibility_invisible?
    assert_predicate @book, :illustrator_visibility_visible?
    assert_not_predicate @book, :illustrator_visibility_invisible?
  end

  test "query state by predicate with custom prefix" do
    assert_predicate @book, :in_english?
    assert_not_predicate @book, :in_spanish?
    assert_not_predicate @book, :in_french?
  end

  test "query state by predicate with custom suffix" do
    assert_predicate @book, :medium_to_read?
    assert_not_predicate @book, :easy_to_read?
    assert_not_predicate @book, :hard_to_read?
  end

  test "enum methods with custom suffix defined" do
    assert_respond_to @book, :easy_to_read?
    assert_respond_to @book, :medium_to_read?
    assert_respond_to @book, :hard_to_read?

    assert_respond_to @book, :easy_to_read!
    assert_respond_to @book, :medium_to_read!
    assert_respond_to @book, :hard_to_read!
  end

  test "update enum attributes with custom suffix" do
    @book.medium_to_read!
    assert_not_predicate @book, :easy_to_read?
    assert_predicate @book, :medium_to_read?
    assert_not_predicate @book, :hard_to_read?

    @book.easy_to_read!
    assert_predicate @book, :easy_to_read?
    assert_not_predicate @book, :medium_to_read?
    assert_not_predicate @book, :hard_to_read?

    @book.hard_to_read!
    assert_not_predicate @book, :easy_to_read?
    assert_not_predicate @book, :medium_to_read?
    assert_predicate @book, :hard_to_read?
  end

  test "data type of Enum type" do
    assert_equal :integer, Book.type_for_attribute("status").type
  end

  test "enum on custom attribute with default" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer, default: 2
      enum status: [:proposed, :written, :published]
    end

    assert_equal "published", klass.new.status
  end

  test "overloaded default by :_default" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      enum status: [:proposed, :written, :published], _default: :published
    end

    assert_equal "published", klass.new.status
  end

  test "overloaded default by :default" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      enum :status, [:proposed, :written, :published], default: :published
    end

    assert_equal "published", klass.new.status
  end

  test "query state by predicate with :prefix" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      attribute :last_read, :integer
      enum :status, { proposed: 0, written: 1 }, prefix: true
      enum :last_read, { unread: 0, reading: 1, read: 2 }, prefix: :being
    end

    book = klass.new
    assert_respond_to book, :status_proposed?
    assert_respond_to book, :being_unread?
  end

  test "query state by predicate with :suffix" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :cover, :integer
      attribute :difficulty, :integer
      enum :cover, { hard: 0, soft: 1 }, suffix: true
      enum :difficulty, { easy: 0, medium: 1, hard: 2 }, suffix: :to_read
    end

    book = klass.new
    assert_respond_to book, :hard_cover?
    assert_respond_to book, :easy_to_read?
  end

  test "option names can be used as label" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer, default: 0
      enum :status, default: 0, scopes: 1, prefix: 2, suffix: 3
    end

    book = klass.new
    assert_predicate book, :default?
    assert_not_predicate book, :scopes?
    assert_not_predicate book, :prefix?
    assert_not_predicate book, :suffix?
  end

  test "capital characters for enum names" do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :extendedWarranty, :integer
      enum extendedWarranty: [:extendedSilver, :extendedGold]
    end

    computer = klass.new(extendedWarranty: :extendedSilver)
    assert_predicate computer, :extendedSilver?
    assert_not_predicate computer, :extendedGold?
  end

  test "unicode characters for enum names" do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :language, :integer
      enum language: [:🇺🇸, :🇪🇸, :🇫🇷]
    end

    book = klass.new(language: :🇺🇸)
    assert_predicate book, :🇺🇸?
    assert_not_predicate book, :🇪🇸?
  end

  test "mangling collision for enum names" do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :timezone, :integer
      enum timezone: [:"Etc/GMT+1", :"Etc/GMT-1"]
    end

    computer = klass.new(timezone: :"Etc/GMT+1")
    assert_predicate computer, :"Etc/GMT+1?"
    assert_not_predicate computer, :"Etc/GMT-1?"
  end

  test "deserialize enum value to original hash key" do
    proposed = Struct.new(:to_s).new("proposed")
    written = Struct.new(:to_s).new("written")
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      enum status: { proposed => 0, written => 1 }
    end

    book = klass.new(status: 0)
    assert_equal proposed, book.status
    assert_predicate book, :proposed?
    assert_not_predicate book, :written?
  end

  test "serializable? with large number label" do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      enum :status, ["9223372036854775808", "-9223372036854775809"]
    end

    type = klass.type_for_attribute(:status)

    assert type.serializable?("9223372036854775808")
    assert type.serializable?("-9223372036854775809")

    assert_not type.serializable?(9223372036854775808)
    assert_not type.serializable?(-9223372036854775809)

    book1 = klass.new(status: "9223372036854775808")
    book2 = klass.new(status: "-9223372036854775809")

    assert_equal 0, book1.status_for_database
    assert_equal 1, book2.status_for_database
  end

  test "raises for attributes with undeclared type" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      enum typeless_genre: [:adventure, :comic]
    end

    error = assert_raises(RuntimeError) do
      klass.type_for_attribute(:typeless_genre)
    end
    assert_match "Undeclared attribute type for enum 'typeless_genre'", error.message
  end

  test "default methods can be disabled by :_instance_methods" do
    klass = Class.new do
      include ActiveModel::Attributes
      include ActiveModel::Enum
      attribute :status, :integer
      enum status: [:proposed, :written], _instance_methods: false
    end

    instance = klass.new
    assert_raises(NoMethodError) { instance.proposed? }
    assert_raises(NoMethodError) { instance.proposed! }
  end
end
