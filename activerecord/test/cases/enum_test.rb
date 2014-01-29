require 'cases/helper'
require 'models/book'

class EnumTest < ActiveRecord::TestCase
  fixtures :books

  setup do
    @book = books(:awdr)
  end

  test "query state by predicate" do
    assert @book.proposed?
    assert_not @book.written?
    assert_not @book.published?

    assert @book.unread?
  end

  test "query state with strings" do
    assert_equal "proposed", @book.status
    assert_equal "unread", @book.read_status
  end

  test "find via scope" do
    assert_equal @book, Book.proposed.first
    assert_equal @book, Book.unread.first
  end

  test "update by declaration" do
    @book.written!
    assert @book.written?
  end

  test "update by setter" do
    @book.update! status: :written
    assert @book.written?
  end

  test "enum methods are overwritable" do
    assert_equal "do publish work...", @book.published!
    assert @book.published?
  end

  test "direct assignment" do
    @book.status = :written
    assert @book.written?
  end

  test "assign string value" do
    @book.status = "written"
    assert @book.written?
  end

  test "enum changed attributes" do
    old_status = @book.status
    @book.status = :published
    assert_equal old_status, @book.changed_attributes[:status]
  end

  test "enum changes" do
    old_status = @book.status
    @book.status = :published
    assert_equal [old_status, 'published'], @book.changes[:status]
  end

  test "enum attribute was" do
    old_status = @book.status
    @book.status = :published
    assert_equal old_status, @book.attribute_was(:status)
  end

  test "enum attribute changed" do
    @book.status = :published
    assert @book.attribute_changed?(:status)
  end

  test "enum attribute changed to" do
    @book.status = :published
    assert @book.attribute_changed?(:status, to: 'published')
  end

  test "enum attribute changed from" do
    old_status = @book.status
    @book.status = :published
    assert @book.attribute_changed?(:status, from: old_status)
  end

  test "enum attribute changed from old status to new status" do
    old_status = @book.status
    @book.status = :published
    assert @book.attribute_changed?(:status, from: old_status, to: 'published')
  end

  test "enum didn't change" do
    old_status = @book.status
    @book.status = old_status
    assert_not @book.attribute_changed?(:status)
  end

  test "persist changes that are dirty" do
    @book.status = :published
    assert @book.attribute_changed?(:status)
    @book.status = :written
    assert @book.attribute_changed?(:status)
  end

  test "reverted changes that are not dirty" do
    old_status = @book.status
    @book.status = :published
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

  test "assign nil value" do
    @book.status = nil
    assert @book.status.nil?
  end

  test "assign empty string value" do
    @book.status = ''
    assert @book.status.nil?
  end

  test "assign long empty string value" do
    @book.status = '   '
    assert @book.status.nil?
  end

  test "constant to access the mapping" do
    assert_equal 0, Book.statuses[:proposed]
    assert_equal 1, Book.statuses["written"]
    assert_equal 2, Book.statuses[:published]
  end

  test "building new objects with enum scopes" do
    assert Book.written.build.written?
    assert Book.read.build.read?
  end

  test "creating new objects with enum scopes" do
    assert Book.written.create.written?
    assert Book.read.create.read?
  end

  test "_before_type_cast returns the enum label (required for form fields)" do
    assert_equal "proposed", @book.status_before_type_cast
  end

  test "reserved enum names" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum status: [:proposed, :written, :published]
    end

    conflicts = [
      :column,     # generates class method .columns, which conflicts with an AR method
      :logger,     # generates #logger, which conflicts with an AR method
      :attributes, # generates #attributes=, which conflicts with an AR method
    ]

    conflicts.each_with_index do |name, i|
      assert_raises(ArgumentError, "enum name `#{name}` should not be allowed") do
        klass.class_eval { enum name => ["value_#{i}"] }
      end
    end
  end

  test "reserved enum values" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum status: [:proposed, :written, :published]
    end

    conflicts = [
      :new,      # generates a scope that conflicts with an AR class method
      :valid,    # generates #valid?, which conflicts with an AR method
      :save,     # generates #save!, which conflicts with an AR method
      :proposed, # same value as an existing enum
    ]

    conflicts.each_with_index do |value, i|
      assert_raises(ArgumentError, "enum value `#{value}` should not be allowed") do
        klass.class_eval { enum "status_#{i}" => [value] }
      end
    end
  end

  test "overriding enum method should not raise" do
    assert_nothing_raised do
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "books"

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
end
