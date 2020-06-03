# frozen_string_literal: true

require "cases/helper"
require "models/book"

class ReadonlyNameBook < Book
  attr_readonly :name
end

class InsertAllTest < ActiveRecord::TestCase
  fixtures :books

  def setup
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
  end

  def teardown
    Arel::Table.engine = ActiveRecord::Base
  end

  def test_insert
    skip unless supports_insert_on_duplicate_skip?

    id = 1_000_000

    assert_difference "Book.count", +1 do
      Book.insert({ id: id, name: "Rework", author_id: 1 })
    end

    Book.upsert({ id: id, name: "Remote", author_id: 1 })

    assert_equal "Remote", Book.find(id).name
  end

  def test_insert!
    assert_difference "Book.count", +1 do
      Book.insert!({ name: "Rework", author_id: 1 })
    end
  end

  def test_insert_all
    assert_difference "Book.count", +10 do
      Book.insert_all! [
        { name: "Rework", author_id: 1 },
        { name: "Patterns of Enterprise Application Architecture", author_id: 1 },
        { name: "Design of Everyday Things", author_id: 1 },
        { name: "Practical Object-Oriented Design in Ruby", author_id: 1 },
        { name: "Clean Code", author_id: 1 },
        { name: "Ruby Under a Microscope", author_id: 1 },
        { name: "The Principles of Product Development Flow", author_id: 1 },
        { name: "Peopleware", author_id: 1 },
        { name: "About Face", author_id: 1 },
        { name: "Eloquent Ruby", author_id: 1 },
      ]
    end
  end

  def test_insert_all_should_handle_empty_arrays
    assert_raise ArgumentError do
      Book.insert_all! []
    end
  end

  def test_insert_all_raises_on_duplicate_records
    assert_raise ActiveRecord::RecordNotUnique do
      Book.insert_all! [
        { name: "Rework", author_id: 1 },
        { name: "Patterns of Enterprise Application Architecture", author_id: 1 },
        { name: "Agile Web Development with Rails", author_id: 1 },
      ]
    end
  end

  def test_insert_all_returns_ActiveRecord_Result
    result = Book.insert_all! [{ name: "Rework", author_id: 1 }]
    assert_kind_of ActiveRecord::Result, result
  end

  def test_insert_all_returns_primary_key_if_returning_is_supported
    skip unless supports_insert_returning?

    result = Book.insert_all! [{ name: "Rework", author_id: 1 }]
    assert_equal %w[ id ], result.columns
  end

  def test_insert_all_returns_nothing_if_returning_is_empty
    skip unless supports_insert_returning?

    result = Book.insert_all! [{ name: "Rework", author_id: 1 }], returning: []
    assert_equal [], result.columns
  end

  def test_insert_all_returns_nothing_if_returning_is_false
    skip unless supports_insert_returning?

    result = Book.insert_all! [{ name: "Rework", author_id: 1 }], returning: false
    assert_equal [], result.columns
  end

  def test_insert_all_returns_requested_fields
    skip unless supports_insert_returning?

    result = Book.insert_all! [{ name: "Rework", author_id: 1 }], returning: [:id, :name]
    assert_equal %w[ Rework ], result.pluck("name")
  end

  def test_insert_all_can_skip_duplicate_records
    skip unless supports_insert_on_duplicate_skip?

    assert_no_difference "Book.count" do
      Book.insert_all [{ id: 1, name: "Agile Web Development with Rails" }]
    end
  end

  def test_insert_all_with_skip_duplicates_and_autonumber_id_not_given
    skip unless supports_insert_on_duplicate_skip?

    assert_difference "Book.count", 1 do
      # These two books are duplicates according to an index on %i[author_id name]
      # but their IDs are not specified so they will be assigned different IDs
      # by autonumber. We will get an exception from MySQL if we attempt to skip
      # one of these records by assigning its ID.
      Book.insert_all [
        { author_id: 8, name: "Refactoring" },
        { author_id: 8, name: "Refactoring" }
      ]
    end
  end

  def test_insert_all_with_skip_duplicates_and_autonumber_id_given
    skip unless supports_insert_on_duplicate_skip?

    assert_difference "Book.count", 1 do
      Book.insert_all [
        { id: 200, author_id: 8, name: "Refactoring" },
        { id: 201, author_id: 8, name: "Refactoring" }
      ]
    end
  end

  def test_skip_duplicates_strategy_does_not_secretly_upsert
    skip unless supports_insert_on_duplicate_skip?

    book = Book.create!(author_id: 8, name: "Refactoring", format: "EXPECTED")

    assert_no_difference "Book.count" do
      Book.insert({ author_id: 8, name: "Refactoring", format: "UNEXPECTED" })
    end

    assert_equal "EXPECTED", book.reload.format
  end

  def test_insert_all_will_raise_if_duplicates_are_skipped_only_for_a_certain_conflict_target
    skip unless supports_insert_on_duplicate_skip? && supports_insert_conflict_target?

    assert_raise ActiveRecord::RecordNotUnique do
      Book.insert_all [{ id: 1, name: "Agile Web Development with Rails" }],
        unique_by: :index_books_on_author_id_and_name
    end
  end

  def test_insert_all_and_upsert_all_with_index_finding_options
    skip unless supports_insert_conflict_target?

    assert_difference "Book.count", +3 do
      Book.insert_all [{ name: "Rework", author_id: 1 }], unique_by: :isbn
      Book.insert_all [{ name: "Remote", author_id: 1 }], unique_by: %i( author_id name )
      Book.insert_all [{ name: "Renote", author_id: 1 }], unique_by: :index_books_on_isbn
    end

    assert_raise ActiveRecord::RecordNotUnique do
      Book.upsert_all [{ name: "Rework", author_id: 1 }], unique_by: :isbn
    end
  end

  def test_insert_all_and_upsert_all_with_expression_index
    skip unless supports_expression_index? && supports_insert_conflict_target?

    book = Book.create!(external_id: "abc")

    assert_no_difference "Book.count" do
      Book.insert_all [{ external_id: "ABC" }], unique_by: :index_books_on_lower_external_id
    end

    Book.upsert_all [{ external_id: "Abc" }], unique_by: :index_books_on_lower_external_id

    assert_equal "Abc", book.reload.external_id
  end

  def test_insert_all_and_upsert_all_raises_when_index_is_missing
    skip unless supports_insert_conflict_target?

    [ :cats, %i( author_id isbn ), :author_id ].each do |missing_or_non_unique_by|
      error = assert_raises ArgumentError do
        Book.insert_all [{ name: "Rework", author_id: 1 }], unique_by: missing_or_non_unique_by
      end
      assert_match "No unique index", error.message

      error = assert_raises ArgumentError do
        Book.upsert_all [{ name: "Rework", author_id: 1 }], unique_by: missing_or_non_unique_by
      end
      assert_match "No unique index", error.message
    end
  end

  def test_insert_logs_message_including_model_name
    skip unless supports_insert_conflict_target?

    capture_log_output do |output|
      Book.insert({ name: "Rework", author_id: 1 })
      assert_match "Book Insert", output.string
    end
  end

  def test_insert_all_logs_message_including_model_name
    skip unless supports_insert_conflict_target?

    capture_log_output do |output|
      Book.insert_all [{ name: "Remote", author_id: 1 }, { name: "Renote", author_id: 1 }]
      assert_match "Book Bulk Insert", output.string
    end
  end

  def test_upsert_logs_message_including_model_name
    skip unless supports_insert_on_duplicate_update?

    capture_log_output do |output|
      Book.upsert({ name: "Remote", author_id: 1 })
      assert_match "Book Upsert", output.string
    end
  end

  def test_upsert_all_logs_message_including_model_name
    skip unless supports_insert_on_duplicate_update?

    capture_log_output do |output|
      Book.upsert_all [{ name: "Remote", author_id: 1 }, { name: "Renote", author_id: 1 }]
      assert_match "Book Bulk Upsert", output.string
    end
  end

  def test_upsert_all_updates_existing_records
    skip unless supports_insert_on_duplicate_update?

    new_name = "Agile Web Development with Rails, 4th Edition"
    Book.upsert_all [{ id: 1, name: new_name }]
    assert_equal new_name, Book.find(1).name
  end

  def test_upsert_all_does_not_update_readonly_attributes
    skip unless supports_insert_on_duplicate_update?

    new_name = "Agile Web Development with Rails, 4th Edition"
    ReadonlyNameBook.upsert_all [{ id: 1, name: new_name }]
    assert_not_equal new_name, Book.find(1).name
  end

  def test_upsert_all_does_not_update_primary_keys
    skip unless supports_insert_on_duplicate_update? && supports_insert_conflict_target?

    Book.upsert_all [{ id: 101, name: "Perelandra", author_id: 7 }]
    Book.upsert_all [{ id: 103, name: "Perelandra", author_id: 7, isbn: "1974522598" }],
      unique_by: :index_books_on_author_id_and_name

    book = Book.find_by(name: "Perelandra")
    assert_equal 101, book.id, "Should not have updated the ID"
    assert_equal "1974522598", book.isbn, "Should have updated the isbn"
  end

  def test_upsert_all_does_not_perform_an_upsert_if_a_partial_index_doesnt_apply
    skip unless supports_insert_on_duplicate_update? && supports_insert_conflict_target? && supports_partial_index?

    Book.upsert_all [{ name: "Out of the Silent Planet", author_id: 7, isbn: "1974522598", published_on: Date.new(1938, 4, 1) }]
    Book.upsert_all [{ name: "Perelandra", author_id: 7, isbn: "1974522598" }],
      unique_by: :index_books_on_isbn

    assert_equal ["Out of the Silent Planet", "Perelandra"], Book.where(isbn: "1974522598").order(:name).pluck(:name)
  end

  def test_insert_all_raises_on_unknown_attribute
    assert_raise ActiveRecord::UnknownAttributeError do
      Book.insert_all! [{ unknown_attribute: "Test" }]
    end
  end

  def test_insert_all_with_enum_values
    Book.insert_all! [{ status: :published, isbn: "1234566", name: "Rework", author_id: 1 },
                      { status: :proposed, isbn: "1234567", name: "Remote", author_id: 2 }]
    assert_equal ["published", "proposed"], Book.where(isbn: ["1234566", "1234567"]).order(:id).pluck(:status)
  end

  private
    def capture_log_output
      output = StringIO.new
      old_logger, ActiveRecord::Base.logger = ActiveRecord::Base.logger, ActiveSupport::Logger.new(output)

      begin
        yield output
      ensure
        ActiveRecord::Base.logger = old_logger
      end
    end
end
