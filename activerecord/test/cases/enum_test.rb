# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/book"
require "active_support/log_subscriber/test_helper"

class EnumTest < ActiveRecord::TestCase
  fixtures :books, :authors, :author_addresses

  setup do
    @book = books(:awdr)
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

  test "find via scope" do
    assert_equal @book, Book.published.first
    assert_equal @book, Book.read.first
    assert_equal @book, Book.in_english.first
    assert_equal @book, Book.author_visibility_visible.first
    assert_equal @book, Book.illustrator_visibility_visible.first
    assert_equal @book, Book.medium_to_read.first
    assert_equal books(:ddd), Book.forgotten.first
    assert_equal books(:rfr), authors(:david).unpublished_books.first
  end

  test "find via negative scope" do
    assert Book.not_published.exclude?(@book)
    assert Book.not_proposed.include?(@book)
  end

  test "find via where with values" do
    published, written = Book.statuses[:published], Book.statuses[:written]

    assert_equal @book, Book.where(status: published).first
    assert_not_equal @book, Book.where(status: written).first
    assert_equal @book, Book.where(status: [published, published]).first
    assert_not_equal @book, Book.where(status: [written, written]).first
    assert_not_equal @book, Book.where.not(status: published).first
    assert_equal @book, Book.where.not(status: written).first
  end

  test "find via where with values.to_s" do
    published, written = Book.statuses[:published].to_s, Book.statuses[:written].to_s

    assert_equal @book, Book.where(status: published).first
    assert_not_equal @book, Book.where(status: written).first
    assert_equal @book, Book.where(status: [published, published]).first
    assert_not_equal @book, Book.where(status: [written, written]).first
    assert_not_equal @book, Book.where.not(status: published).first
    assert_equal @book, Book.where.not(status: written).first
    assert_equal @book, Book.where(cover: Book.covers[:soft]).first
  end

  test "find via where with symbols" do
    assert_equal @book, Book.where(status: :published).first
    assert_not_equal @book, Book.where(status: :written).first
    assert_equal @book, Book.where(status: [:published, :published]).first
    assert_not_equal @book, Book.where(status: [:written, :written]).first
    assert_not_equal @book, Book.where.not(status: :published).first
    assert_equal @book, Book.where.not(status: :written).first
    assert_equal books(:ddd), Book.where(last_read: :forgotten).first
    assert_nil Book.where(status: :prohibited).first
    assert_equal @book, Book.where(cover: :soft).first
    assert_equal @book, Book.where.not(cover: :hard).first
  end

  test "find via where with strings" do
    assert_equal @book, Book.where(status: "published").first
    assert_not_equal @book, Book.where(status: "written").first
    assert_equal @book, Book.where(status: ["published", "published"]).first
    assert_not_equal @book, Book.where(status: ["written", "written"]).first
    assert_not_equal @book, Book.where.not(status: "published").first
    assert_equal @book, Book.where.not(status: "written").first
    assert_equal books(:ddd), Book.where(last_read: "forgotten").first
    assert_nil Book.where(status: "prohibited").first
  end

  test "find via where with large number" do
    assert_equal @book, Book.where(status: [2, 9223372036854775808]).first
    assert_equal @book, Book.where(status: ["2", "9223372036854775808"]).first
    assert_equal @book, Book.where(status: 2..9223372036854775808).first
    assert_equal @book, Book.where(status: "2".."9223372036854775808").first
  end

  test "find via where should be type casted" do
    book = Book.enabled.create!
    assert_predicate book, :enabled?

    enabled = Book.boolean_statuses[:enabled].to_s
    assert_equal book, Book.where(boolean_status: enabled).last
    assert_equal @book, Book.where(cover: "soft").first
    assert_equal @book, Book.where.not(cover: "hard").first
  end

  test "build from scope" do
    assert_predicate Book.written.build, :written?
    assert_not_predicate Book.written.build, :proposed?
    assert_predicate PublishedBook.hard.build, :hard?
    assert_not_predicate PublishedBook.hard.build, :soft?
  end

  test "build from where" do
    assert_predicate Book.where(status: Book.statuses[:written]).build, :written?
    assert_not_predicate Book.where(status: Book.statuses[:written]).build, :proposed?
    assert_predicate Book.where(status: :written).build, :written?
    assert_not_predicate Book.where(status: :written).build, :proposed?
    assert_predicate Book.where(status: "written").build, :written?
    assert_not_predicate Book.where(status: "written").build, :proposed?
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

  test "update by setter" do
    @book.update! status: :written
    assert_predicate @book, :written?
    @book.update! cover: :hard
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
    book = Book.create!(nullable_status: nil)

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
    klass = Class.new(ActiveRecord::Base) do
      def self.name; "Book"; end
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
    klass = Class.new(ActiveRecord::Base) do
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

  test "NULL values from database should be casted to nil" do
    Book.where(id: @book.id).update_all("status = NULL")
    assert_nil @book.reload.status
  end

  test "deserialize nil value to enum which defines nil value to hash" do
    assert_equal "forgotten", books(:ddd).last_read
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

  test "building new objects with enum scopes" do
    assert_predicate Book.written.build, :written?
    assert_predicate Book.read.build, :read?
    assert_predicate Book.in_spanish.build, :in_spanish?
    assert_predicate Book.illustrator_visibility_invisible.build, :illustrator_visibility_invisible?
  end

  test "creating new objects with enum scopes" do
    assert_predicate Book.written.create, :written?
    assert_predicate Book.read.create, :read?
    assert_predicate Book.in_spanish.create, :in_spanish?
    assert_predicate Book.illustrator_visibility_invisible.create, :illustrator_visibility_invisible?
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
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status
      end
    end

    assert_match(/must not be empty\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum(:status, {}, **{})
      end
    end

    assert_match(/must not be empty\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, []
      end
    end

    assert_match(/must not be empty\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, [proposed: 1, written: 2, published: 3]
      end
    end

    assert_match(/must only contain symbols or strings\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, { "" => 1, "active" => 2 }
      end
    end

    assert_match(/must not contain a blank name\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, ["active", ""]
      end
    end

    assert_match(/must not contain a blank name\.$/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, { proposed: Object.new, active: :active }
      end
    end

    assert_match(/must be only booleans, integers, symbols or strings/, e.message)

    e = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, Object.new
      end
    end

    assert_match(/must be either a non-empty hash or an array\.$/, e.message)
  end

  test "reserved enum names" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, [:proposed, :written, :published]
    end

    conflicts = [
      :column,     # generates class method .columns, which conflicts with an AR method
      :logger,     # generates #logger, which conflicts with an AR method
      :attributes, # generates #attributes=, which conflicts with an AR method
    ]

    conflicts.each_with_index do |name, i|
      e = assert_raises(ArgumentError) do
        klass.class_eval { enum name, ["value_#{i}"] }
      end
      assert_match(/You tried to define an enum named "#{name}" on the model/, e.message)
    end
  end

  test "reserved enum values" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, [:proposed, :written, :published]
    end

    conflicts = [
      :new,      # generates a scope that conflicts with an AR class method
      :valid,    # generates #valid?, which conflicts with an AR method
      :save,     # generates #save!, which conflicts with an AR method
      :proposed, # same value as an existing enum
      :public, :private, :protected, # some important methods on Module and Class
      :name, :superclass,
      :id        # conflicts with AR querying
    ]

    conflicts.each_with_index do |value, i|
      e = assert_raises(ArgumentError, "enum value `#{value}` should not be allowed") do
        klass.class_eval { enum "status_#{i}", [value] }
      end
      assert_match(/You tried to define an enum named .* on the model/, e.message)
    end
  end

  test "can use id as a value with a prefix or suffix" do
    assert_nothing_raised do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status_1, [:id], prefix: true
        enum :status_2, [:id], suffix: true
      end
    end
  end

  test "reserved enum values for relation" do
    relation_method_samples = [
      :records,
      :to_ary,
      :scope_for_create
    ]

    relation_method_samples.each do |value|
      e = assert_raises(ArgumentError, "enum value `#{value}` should not be allowed") do
        Class.new(ActiveRecord::Base) do
          self.table_name = "books"
          enum :category, [:other, value]
        end
      end
      assert_match(/You tried to define an enum named .* on the model/, e.message)
    end
  end

  test "overriding enum method should not raise" do
    assert_nothing_raised do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"

        def published!
          super
          "do publish work..."
        end

        enum :status, [:proposed, :written, :published]

        def written!
          super
          "do written work..."
        end
      end
    end
  end

  test "validate uniqueness" do
    klass = Class.new(ActiveRecord::Base) do
      def self.name; "Book"; end
      enum :status, [:proposed, :written]
      validates_uniqueness_of :status
    end
    klass.delete_all
    klass.create!(status: "proposed")
    book = klass.new(status: "written")
    assert_predicate book, :valid?
    book.status = "proposed"
    assert_not_predicate book, :valid?
  end

  test "validate inclusion of value in array" do
    klass = Class.new(ActiveRecord::Base) do
      def self.name; "Book"; end
      enum :status, [:proposed, :written]
      validates_inclusion_of :status, in: ["written"]
    end
    invalid_book = klass.new(status: "proposed")
    assert_not_predicate invalid_book, :valid?
    valid_book = klass.new(status: "written")
    assert_predicate valid_book, :valid?
  end

  test "enums are distinct per class" do
    klass1 = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, [:proposed, :written]
    end

    klass2 = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, [:drafted, :uploaded]
    end

    book1 = klass1.proposed.create!
    book1.status = :written
    assert_equal ["proposed", "written"], book1.status_change

    book2 = klass2.drafted.create!
    book2.status = :uploaded
    assert_equal ["drafted", "uploaded"], book2.status_change
  end

  test "enums are inheritable" do
    subklass1 = Class.new(Book)

    subklass2 = Class.new(Book) do
      enum :status, [:drafted, :uploaded]
    end

    book1 = subklass1.proposed.create!
    book1.status = :written
    assert_equal ["proposed", "written"], book1.status_change

    book2 = subklass2.drafted.create!
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

  test "declare multiple enums with prefix: true" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"

      enum(:status, [:value_1], prefix: true)

      enum(:last_read, [:value_1], prefix: true)
    end

    instance = klass.new
    assert_respond_to instance, :status_value_1?
    assert_respond_to instance, :last_read_value_1?
  end

  test "declare multiple enums with suffix: true" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"

      enum(:status, [:value_1], suffix: true)

      enum(:last_read, [:value_1], suffix: true)
    end

    instance = klass.new
    assert_respond_to instance, :value_1_status?
    assert_respond_to instance, :value_1_last_read?
  end

  test "enum with alias_attribute" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      alias_attribute :aliased_status, :status
      enum :aliased_status, [:proposed, :written, :published]
    end

    book = klass.proposed.create!
    assert_predicate book, :proposed?
    assert_equal "proposed", book.aliased_status

    book = klass.find(book.id)
    assert_predicate book, :proposed?
    assert_equal "proposed", book.aliased_status
  end

  test "enum with a hash with symbol values" do
    book = Book.create!(symbol_status: :proposed)
    assert_equal "proposed", book.symbol_status
    assert_predicate book, :symbol_status_proposed?
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
    assert_respond_to @book.class, :easy_to_read
    assert_respond_to @book.class, :medium_to_read
    assert_respond_to @book.class, :hard_to_read

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

  test "uses default status when no status is provided in fixtures" do
    book = books(:tlg)
    assert_predicate book, :proposed?, "expected fixture to default to proposed status"
    assert_predicate book, :in_english?, "expected fixture to default to english language"
  end

  test "uses default value from database on initialization" do
    book = Book.new
    assert_predicate book, :proposed?
  end

  test "uses default value from database on initialization when using custom mapping" do
    book = Book.new
    assert_predicate book, :hard?
  end

  test "data type of Enum type" do
    assert_equal :integer, Book.type_for_attribute("status").type
  end

  test "enum on custom attribute with default" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      attribute :status, default: 2
      enum :status, [:proposed, :written, :published]
    end

    assert_equal "published", klass.new.status
  end

  test "overloaded default by :default" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, [:proposed, :written, :published], default: :published
    end

    assert_equal "published", klass.new.status
  end

  test ":_default is invalid in the new API" do
    error = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, [:proposed, :written, :published], _default: :published
      end
    end

    assert_match(/invalid option\(s\): :_default/, error.message)
  end

  test ":_prefix is invalid in the new API" do
    error = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, [:proposed, :written, :published], _prefix: true
      end
    end

    assert_match(/invalid option\(s\): :_prefix/, error.message)
  end

  test ":_suffix is invalid in the new API" do
    error = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, [:proposed, :written, :published], _suffix: true
      end
    end

    assert_match(/invalid option\(s\): :_suffix/, error.message)
  end

  test ":_scopes is invalid in the new API" do
    error = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, [:proposed, :written, :published], _scopes: false
      end
    end

    assert_match(/invalid option\(s\): :_scopes/, error.message)
  end

  test ":_instance_methods is invalid in the new API" do
    error = assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        enum :status, [:proposed, :written, :published], _instance_methods: false
      end
    end

    assert_match(/invalid option\(s\): :_instance_methods/, error.message)
  end

  test "scopes can be disabled by :scopes" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, [:proposed, :written], scopes: false
    end

    assert_raises(NoMethodError) { klass.proposed }
  end

  test "query state by predicate with :prefix" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, { proposed: 0, written: 1 }, prefix: true
      enum :last_read, { unread: 0, reading: 1, read: 2 }, prefix: :being
    end

    book = klass.new
    assert_respond_to book, :status_proposed?
    assert_respond_to book, :being_unread?
  end

  test "query state by predicate with :suffix" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :cover, { hard: 0, soft: 1 }, suffix: true
      enum :difficulty, { easy: 0, medium: 1, hard: 2 }, suffix: :to_read
    end

    book = klass.new
    assert_respond_to book, :hard_cover?
    assert_respond_to book, :easy_to_read?
  end

  test "enum labels as keyword arguments" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, active: 0, archived: 1
    end

    book = klass.new
    assert_predicate book, :active?
    assert_not_predicate book, :archived?
  end

  test "option names can be used as label" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, default: 0, scopes: 1, prefix: 2, suffix: 3
      enum :last_read, { default: 0, scopes: 1, prefix: 2, suffix: 3 }, prefix: "p", suffix: true
    end

    book = klass.new
    assert_predicate book, :default?
    assert_not_predicate book, :scopes?
    assert_not_predicate book, :prefix?
    assert_not_predicate book, :suffix?

    assert_predicate book, :p_default_last_read?
    assert_not_predicate book, :p_scopes_last_read?
    assert_not_predicate book, :p_prefix_last_read?
    assert_not_predicate book, :p_suffix_last_read?
  end

  test "scopes are named like methods" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "cats"
      enum :breed, { "American Bobtail" => 0, "Balinese-Javanese" => 1 }
    end

    assert_respond_to klass, :American_Bobtail
    assert_respond_to klass, :Balinese_Javanese
  end

  test "capital characters for enum names" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "computers"
      enum :extendedWarranty, [:extendedSilver, :extendedGold]
    end

    computer = klass.extendedSilver.build
    assert_predicate computer, :extendedSilver?
    assert_not_predicate computer, :extendedGold?
  end

  test "unicode characters for enum names" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :language, [:🇺🇸, :🇪🇸, :🇫🇷]
    end

    book = klass.🇺🇸.build
    assert_predicate book, :🇺🇸?
    assert_not_predicate book, :🇪🇸?
  end

  test "mangling collision for enum names" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "computers"
      enum :timezone, [:"Etc/GMT+1", :"Etc/GMT-1"]
    end

    computer = klass.public_send(:"Etc/GMT+1").build
    assert_predicate computer, :"Etc/GMT+1?"
    assert_not_predicate computer, :"Etc/GMT-1?"
  end

  test "deserialize enum value to original hash key" do
    proposed = Struct.new(:to_s).new("proposed")
    written = Struct.new(:to_s).new("written")
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, { proposed => 0, written => 1 }
    end

    book = klass.create!(status: 0)
    assert_equal proposed, book.status
    assert_predicate book, :proposed?
    assert_not_predicate book, :written?
  end

  test "serializable? with large number label" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, ["9223372036854775808", "-9223372036854775809"]
    end

    type = klass.type_for_attribute(:status)

    assert type.serializable?("9223372036854775808")
    assert type.serializable?("-9223372036854775809")

    assert_not type.serializable?(9223372036854775808)
    assert_not type.serializable?(-9223372036854775809)

    book1 = klass.create!(status: "9223372036854775808")
    book2 = klass.create!(status: "-9223372036854775809")

    assert_equal 0, book1.status_for_database
    assert_equal 1, book2.status_for_database

    assert_equal book1, klass.where(status: "9223372036854775808").last
    assert_equal book2, klass.where(status: "-9223372036854775809").last
  end

  test "enum logs a warning if auto-generated negative scopes would clash with other enum names" do
    old_logger = ActiveRecord::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

    ActiveRecord::Base.logger = logger

    expected_message_1 = "Enum element 'not_sent' in Book uses the prefix 'not_'."\
      " This has caused a conflict with auto generated negative scopes."\
      " Avoid using enum elements starting with 'not' where the positive form is also an element."

    Class.new(ActiveRecord::Base) do
      def self.name
        "Book"
      end
      silence_warnings do
        enum :status, [:sent, :not_sent]
      end
    end

    assert_includes(logger.logged(:warn), expected_message_1)
  ensure
    ActiveRecord::Base.logger = old_logger
  end

  test "enum logs a warning if auto-generated negative scopes would clash with other enum names regardless of order" do
    old_logger = ActiveRecord::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

    ActiveRecord::Base.logger = logger

    expected_message_1 = "Enum element 'not_sent' in Book uses the prefix 'not_'."\
      " This has caused a conflict with auto generated negative scopes."\
      " Avoid using enum elements starting with 'not' where the positive form is also an element."

    Class.new(ActiveRecord::Base) do
      def self.name
        "Book"
      end
      silence_warnings do
        enum :status, [:not_sent, :sent]
      end
    end

    assert_includes(logger.logged(:warn), expected_message_1)
  ensure
    ActiveRecord::Base.logger = old_logger
  end

  test "enum doesn't log a warning if no clashes detected" do
    old_logger = ActiveRecord::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

    ActiveRecord::Base.logger = logger

    Class.new(ActiveRecord::Base) do
      def self.name
        "Book"
      end
      enum :status, [:not_sent]
    end

    assert_empty(logger.logged(:warn))
  ensure
    ActiveRecord::Base.logger = old_logger
  end

  test "enum doesn't log a warning if opting out of scopes" do
    old_logger = ActiveRecord::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

    ActiveRecord::Base.logger = logger

    Class.new(ActiveRecord::Base) do
      def self.name
        "Book"
      end
      silence_warnings do
        enum :status, [:not_sent, :sent], scopes: false
      end
    end

    assert_empty(logger.logged(:warn))
  ensure
    ActiveRecord::Base.logger = old_logger
  end

  test "raises for attributes with undeclared type" do
    klass = Class.new(Book) do
    def self.name; "Book"; end
    enum :typeless_genre, [:adventure, :comic]
  end

    error = assert_raises(RuntimeError) do
      klass.type_for_attribute(:typeless_genre)
    end
    assert_match "Undeclared attribute type for enum 'typeless_genre' in Book", error.message
  end

  test "supports attributes declared with a explicit type" do
    klass = Class.new(Book) do
      attribute :my_genre, :integer
      enum :my_genre, [:adventure, :comic]
    end

    assert_equal :integer, klass.type_for_attribute(:my_genre).type
  end

  test "default methods can be disabled by :instance_methods" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum :status, [:proposed, :written], instance_methods: false
    end

    instance = klass.new
    assert_raises(NoMethodError) { instance.proposed? }
    assert_raises(NoMethodError) { instance.proposed! }
  end
end
