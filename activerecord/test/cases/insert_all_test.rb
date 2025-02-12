# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/book"
require "models/category"
require "models/cart"
require "models/developer"
require "models/ship"
require "models/speedometer"
require "models/subscription"
require "models/subscriber"

class ReadonlyNameBook < Book
  attr_readonly :name
end

class InsertAllTest < ActiveRecord::TestCase
  fixtures :books

  def setup
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
    @original_db_warnings_action = :ignore
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

  def test_insert_with_type_casting_and_serialize_is_consistent
    skip unless supports_insert_returning?

    book_name = ["Array"]
    created_book_id = Book.create!(name: book_name).id
    inserted_book_id = Book.insert!({ name: book_name }, returning: :id).first["id"]
    created_book = Book.find_by!(id: created_book_id)
    inserted_book = Book.find_by!(id: inserted_book_id)
    assert_equal created_book.name, inserted_book.name
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
    skip unless supports_insert_on_duplicate_update?

    assert_empty Book.insert_all([])
    assert_empty Book.insert_all!([])
    assert_empty Book.upsert_all([])
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

  def test_insert_all_returns_requested_sql_fields
    skip unless supports_insert_returning?

    result = Book.insert_all! [{ name: "Rework", author_id: 1 }], returning: Arel.sql("UPPER(name) as name")
    assert_equal %w[ REWORK ], result.pluck("name")
  end

  def test_insert_all_can_skip_duplicate_records
    skip unless supports_insert_on_duplicate_skip?

    assert_no_difference "Book.count" do
      Book.insert_all [{ id: 1, name: "Agile Web Development with Rails" }]
    end
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_insert_all_generates_correct_sql
      skip unless supports_insert_on_duplicate_skip?

      assert_queries_match(/ON DUPLICATE KEY UPDATE/) do
        Book.insert_all [{ id: 1, name: "Agile Web Development with Rails" }]
      end
    end

    def test_insert_all_succeeds_when_passed_no_attributes
      skip unless supports_insert_on_duplicate_skip?

      assert_nothing_raised do
        Book.insert_all [{}]
      end
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

    book = Book.create!(format: "EXPECTED", author_id: 8, name: "Refactoring")

    assert_no_difference "Book.count" do
      Book.insert_all([{ format: "UNEXPECTED", author_id: 8, name: "Refactoring" }])
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

    assert_difference "Book.count", +4 do
      Book.insert_all [{ name: "Rework", author_id: 1 }], unique_by: :isbn
      Book.insert_all [{ name: "Remote", author_id: 1 }], unique_by: %i( author_id name )
      Book.insert_all [{ name: "Renote", author_id: 1 }], unique_by: :index_books_on_isbn
      Book.insert_all [{ name: "Recoat", author_id: 1 }], unique_by: :id
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

  def test_insert_all_and_upsert_all_finds_index_with_inverted_unique_by_columns
    skip unless supports_insert_conflict_target?

    columns = [:author_id, :name]
    assert ActiveRecord::Base.lease_connection.index_exists?(:books, columns)

    assert_difference "Book.count", +2 do
      Book.insert_all [{ name: "Remote", author_id: 1 }], unique_by: columns.reverse
      Book.upsert_all [{ name: "Rework", author_id: 1 }], unique_by: columns.reverse
    end
  end

  def test_insert_all_and_upsert_all_works_with_composite_primary_keys_when_unique_by_is_provided
    skip unless supports_insert_conflict_target?

    assert_difference "Cart.count", 2 do
      Cart.insert_all [{ id: 1, shop_id: 1, title: "My cart" }], unique_by: [:shop_id, :id]

      Cart.upsert_all [{ id: 3, shop_id: 2, title: "My other cart" }], unique_by: [:shop_id, :id]
    end

    error = assert_raises ArgumentError do
      Cart.insert_all! [{ id: 2, shop_id: 1, title: "My cart" }]
    end
    assert_match "No unique index found for id", error.message
  end

  def test_insert_all_and_upsert_all_works_with_composite_primary_keys_when_unique_by_is_not_provided
    skip unless supports_insert_on_duplicate_skip? && !supports_insert_conflict_target?

    assert_difference "Cart.count", 3 do
      Cart.insert_all [{ id: 1, shop_id: 1, title: "My cart" }]

      Cart.insert_all! [{ id: 2, shop_id: 1, title: "My cart 2" }]

      Cart.upsert_all [{ id: 3, shop_id: 2, title: "My other cart" }]
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

  def test_insert_all_and_upsert_all_with_aliased_attributes
    skip unless supports_insert_on_duplicate_update?

    if supports_insert_returning?
      assert_difference "Book.count" do
        result = Book.insert_all [{ title: "Remote", author_id: 1 }], returning: :title
        assert_includes result.columns, "title"
      end
    end

    Book.upsert_all [{ id: 101, title: "Perelandra", author_id: 7, isbn: "1974522598" }]
    Book.upsert_all [{ id: 101, title: "Perelandra 2", author_id: 6, isbn: "111111" }], update_only: %i[ title isbn ]

    book = Book.find(101)
    assert_equal "Perelandra 2", book.title, "Should have updated the title"
    assert_equal "111111", book.isbn, "Should have updated the isbn"
    assert_equal 7, book.author_id, "Should not have updated the author_id"
  end

  def test_insert_all_and_upsert_all_with_sti
    skip unless supports_insert_on_duplicate_update?

    assert_difference -> { Category.count }, 2 do
      SpecialCategory.insert_all [{ name: "First" }, { name: "Second", type: nil }]
    end

    first, second = Category.last(2)
    assert_equal "SpecialCategory", first.type
    assert_nil second.type

    SpecialCategory.upsert_all [{ id: 103, name: "First" }, { id: 104, name: "Second", type: nil }]

    category3 = Category.find(103)
    assert_equal "SpecialCategory", category3.type

    category4 = Category.find(104)
    assert_nil category4.type
  end

  def test_upsert_logs_message_including_model_name
    skip unless supports_insert_on_duplicate_update?

    capture_log_output do |output|
      Book.upsert({ name: "Remote", author_id: 1 })
      assert_match "Book Upsert", output.string
    end
  end

  unless in_memory_db?
    def test_upsert_and_db_warnings
      skip unless supports_insert_on_duplicate_update?

      begin
        with_db_warnings_action(:raise) do
          assert_nothing_raised do
            Book.upsert({ id: 1001, name: "Remote", author_id: 1 })
          end
        end
      ensure
        # We need to explicitly remove the record, because `with_db_warnings_action`
        # prevents the wrapping transaction to be rolled back.
        Book.delete(1001)
      end
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

  def test_upsert_all_updates_existing_record_by_primary_key
    skip unless supports_insert_conflict_target?

    Book.upsert_all [{ id: 1, name: "New edition" }], unique_by: :id

    assert_equal "New edition", Book.find(1).name
  end

  def test_upsert_all_does_notupdates_existing_record_by_when_there_is_no_key
    skip unless supports_insert_on_duplicate_update? && !supports_insert_conflict_target?

    Speedometer.create!(speedometer_id: "s3", name: "Very fast")

    Speedometer.upsert_all [{ speedometer_id: "s3", name: "New Speedometer" }]

    assert_equal "Very fast", Speedometer.find("s3").name
  end

  def test_upsert_all_updates_existing_record_by_configured_primary_key_fails_when_database_supports_insert_conflict_target
    skip unless supports_insert_on_duplicate_update? && supports_insert_conflict_target?

    error = assert_raises ArgumentError do
      Speedometer.upsert_all [{ speedometer_id: "s1", name: "New Speedometer" }]
    end
    assert_match "No unique index found for speedometer_id", error.message
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

  def test_upsert_all_passing_both_on_duplicate_and_update_only_will_raise_an_error
    assert_raises ArgumentError do
      Book.upsert_all [{ id: 101, name: "Perelandra", author_id: 7, isbn: "1974522598" }], on_duplicate: "NAME=values(name)", update_only: :name
    end
  end

  def test_upsert_all_only_updates_the_column_provided_via_update_only
    skip unless supports_insert_on_duplicate_update?

    Book.upsert_all [{ id: 101, name: "Perelandra", author_id: 7, isbn: "1974522598" }]
    Book.upsert_all [{ id: 101, name: "Perelandra 2", author_id: 7, isbn: "111111" }], update_only: :name

    book = Book.find(101)
    assert_equal "Perelandra 2", book.name, "Should have updated the name"
    assert_equal "1974522598", book.isbn, "Should not have updated the isbn"
  end

  def test_upsert_all_only_updates_the_list_of_columns_provided_via_update_only
    skip unless supports_insert_on_duplicate_update?

    Book.upsert_all [{ id: 101, name: "Perelandra", author_id: 7, isbn: "1974522598" }]
    Book.upsert_all [{ id: 101, name: "Perelandra 2", author_id: 6, isbn: "111111" }], update_only: %i[ name isbn ]

    book = Book.find(101)
    assert_equal "Perelandra 2", book.name, "Should have updated the name"
    assert_equal "111111", book.isbn, "Should have updated the isbn"
    assert_equal 7, book.author_id, "Should not have updated the author_id"
  end

  def test_upsert_all_does_not_perform_an_upsert_if_a_partial_index_doesnt_apply
    skip unless supports_insert_on_duplicate_update? && supports_insert_conflict_target? && supports_partial_index?

    Book.upsert_all [{ name: "Out of the Silent Planet", author_id: 7, isbn: "1974522598", published_on: Date.new(1938, 4, 1) }]
    Book.upsert_all [{ name: "Perelandra", author_id: 7, isbn: "1974522598" }],
      unique_by: :index_books_on_isbn

    assert_equal ["Out of the Silent Planet", "Perelandra"], Book.where(isbn: "1974522598").order(:name).pluck(:name)
  end

  def test_upsert_all_does_not_touch_updated_at_when_values_do_not_change
    skip unless supports_insert_on_duplicate_update?

    updated_at = Time.now.utc - 5.years
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: updated_at }]
    Book.upsert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1) }]

    assert_in_delta updated_at, Book.find(101).updated_at, 1
  end

  def test_upsert_all_touches_updated_at_and_updated_on_when_values_change
    skip unless supports_insert_on_duplicate_update?

    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
    Book.upsert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) }]

    assert_equal Time.now.utc.year, Book.find(101).updated_at.year
    assert_equal Time.now.utc.year, Book.find(101).updated_on.year
  end

  def test_upsert_all_respects_updated_at_precision_when_touched_implicitly
    skip unless supports_insert_on_duplicate_update?

    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]

    # A single upsert can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.upsert_all [{ id: 101, name: "Out of the Silent Planet (Edition #{i})" }]
      Book.find(101).updated_at.usec > 0
    end

    assert has_subsecond_precision, "updated_at should have sub-second precision"
  end

  def test_upsert_all_uses_given_updated_at_over_implicit_updated_at
    skip unless supports_insert_on_duplicate_update?

    updated_at = Time.now.utc - 1.year
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago }]
    Book.upsert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_at: updated_at }]

    assert_in_delta updated_at, Book.find(101).updated_at, 1
  end

  def test_upsert_all_uses_given_updated_on_over_implicit_updated_on
    skip unless supports_insert_on_duplicate_update?

    updated_on = Time.now.utc.to_date - 30
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_on: 5.years.ago }]
    Book.upsert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_on: updated_on }]

    assert_equal updated_on, Book.find(101).updated_on
  end

  def test_upsert_all_implicitly_sets_timestamps_on_create_when_model_record_timestamps_is_true
    skip unless supports_insert_on_duplicate_update?

    with_record_timestamps(Ship, true) do
      Ship.upsert_all [{ id: 101, name: "RSS Boaty McBoatface" }]

      ship = Ship.find(101)
      assert_equal Time.new.utc.year, ship.created_at.year
      assert_equal Time.new.utc.year, ship.created_on.year
      assert_equal Time.new.utc.year, ship.updated_at.year
      assert_equal Time.new.utc.year, ship.updated_on.year
    end
  end

  def test_upsert_all_does_not_implicitly_set_timestamps_on_create_when_model_record_timestamps_is_true_but_overridden
    skip unless supports_insert_on_duplicate_update?

    with_record_timestamps(Ship, true) do
      Ship.upsert_all [{ id: 101, name: "RSS Boaty McBoatface" }], record_timestamps: false

      ship = Ship.find(101)
      assert_nil ship.created_at
      assert_nil ship.created_on
      assert_nil ship.updated_at
      assert_nil ship.updated_on
    end
  end

  def test_upsert_all_does_not_implicitly_set_timestamps_on_create_when_model_record_timestamps_is_false
    skip unless supports_insert_on_duplicate_update?

    with_record_timestamps(Ship, false) do
      Ship.upsert_all [{ id: 101, name: "RSS Boaty McBoatface" }]

      ship = Ship.find(101)
      assert_nil ship.created_at
      assert_nil ship.created_on
      assert_nil ship.updated_at
      assert_nil ship.updated_on
    end
  end

  def test_upsert_all_implicitly_sets_timestamps_on_create_when_model_record_timestamps_is_false_but_overridden
    skip unless supports_insert_on_duplicate_update?

    with_record_timestamps(Ship, false) do
      Ship.upsert_all [{ id: 101, name: "RSS Boaty McBoatface" }], record_timestamps: true

      ship = Ship.find(101)
      assert_equal Time.now.utc.year, ship.created_at.year
      assert_equal Time.now.utc.year, ship.created_on.year
      assert_equal Time.now.utc.year, ship.updated_at.year
      assert_equal Time.now.utc.year, ship.updated_on.year
    end
  end

  def test_upsert_all_respects_created_at_precision_when_touched_implicitly
    skip unless supports_insert_on_duplicate_update?

    # A single upsert can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.upsert_all [{ id: 101 + i, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1) }]
      Book.find(101 + i).created_at.usec > 0
    end

    assert has_subsecond_precision, "created_at should have sub-second precision"
  end

  def test_upsert_all_implicitly_sets_timestamps_on_update_when_model_record_timestamps_is_true
    skip unless supports_insert_on_duplicate_update?

    with_record_timestamps(Ship, true) do
      travel_to(Date.new(2016, 4, 17)) { Ship.create! id: 101, name: "RSS Boaty McBoatface" }

      Ship.upsert_all [{ id: 101, name: "RSS Sir David Attenborough" }]

      ship = Ship.find(101)
      assert_equal 2016, ship.created_at.year
      assert_equal 2016, ship.created_on.year
      assert_equal Time.now.utc.year, ship.updated_at.year
      assert_equal Time.now.utc.year, ship.updated_on.year
    end
  end

  def test_upsert_all_does_not_implicitly_set_timestamps_on_update_when_model_record_timestamps_is_true_but_overridden
    skip unless supports_insert_on_duplicate_update?

    with_record_timestamps(Ship, true) do
      travel_to(Date.new(2016, 4, 17)) { Ship.create! id: 101, name: "RSS Boaty McBoatface" }

      Ship.upsert_all [{ id: 101, name: "RSS Sir David Attenborough" }], record_timestamps: false

      ship = Ship.find(101)
      assert_equal 2016, ship.created_at.year
      assert_equal 2016, ship.created_on.year
      assert_equal 2016, ship.updated_at.year
      assert_equal 2016, ship.updated_on.year
    end
  end

  def test_upsert_all_does_not_implicitly_set_timestamps_on_update_when_model_record_timestamps_is_false
    skip unless supports_insert_on_duplicate_update?

    with_record_timestamps(Ship, false) do
      Ship.create! id: 101, name: "RSS Boaty McBoatface"

      Ship.upsert_all [{ id: 101, name: "RSS Sir David Attenborough" }]

      ship = Ship.find(101)
      assert_nil ship.created_at
      assert_nil ship.created_on
      assert_nil ship.updated_at
      assert_nil ship.updated_on
    end
  end

  def test_upsert_all_implicitly_sets_timestamps_on_update_when_model_record_timestamps_is_false_but_overridden
    skip unless supports_insert_on_duplicate_update?

    with_record_timestamps(Ship, false) do
      Ship.create! id: 101, name: "RSS Boaty McBoatface"

      Ship.upsert_all [{ id: 101, name: "RSS Sir David Attenborough" }], record_timestamps: true

      ship = Ship.find(101)
      assert_nil ship.created_at
      assert_nil ship.created_on
      assert_equal Time.now.utc.year, ship.updated_at.year
      assert_equal Time.now.utc.year, ship.updated_on.year
    end
  end

  def test_upsert_all_implicitly_sets_timestamps_even_when_columns_are_aliased
    skip unless supports_insert_on_duplicate_update?

    Developer.upsert_all [{ id: 101, name: "Alice" }]
    alice = Developer.find(101)

    assert_not_nil alice.created_at
    assert_not_nil alice.created_on
    assert_not_nil alice.updated_at
    assert_not_nil alice.updated_on

    alice.update!(created_at: nil, created_on: nil, updated_at: nil, updated_on: nil)

    Developer.upsert_all [{ id: alice.id, name: alice.name, salary: alice.salary * 2 }]
    alice.reload

    assert_nil alice.created_at
    assert_nil alice.created_on
    assert_not_nil alice.updated_at
    assert_not_nil alice.updated_on
  end

  def test_insert_all_raises_on_unknown_attribute
    assert_raise ActiveRecord::UnknownAttributeError do
      Book.insert_all! [{ unknown_attribute: "Test" }]
    end
  end

  def test_upsert_all_works_with_partitioned_indexes
    skip unless supports_insert_on_duplicate_update? && supports_insert_conflict_target? && supports_partitioned_indexes?

    require "models/measurement"

    Measurement.upsert_all([{ city_id: "1", logdate: 1.days.ago, peaktemp: 1, unitsales: 1 },
                            { city_id: "2", logdate: 2.days.ago, peaktemp: 2, unitsales: 2 },
                            { city_id: "2", logdate: 3.days.ago, peaktemp: 0, unitsales: 0 }],
                            unique_by: %i[logdate city_id])
    assert_equal [[1.day.ago.to_date, 1, 1]],
                 Measurement.where(city_id: 1).pluck(:logdate, :peaktemp, :unitsales)
    assert_equal [[2.days.ago.to_date, 2, 2], [3.days.ago.to_date, 0, 0]],
                 Measurement.where(city_id: 2).pluck(:logdate, :peaktemp, :unitsales)
  end

  def test_insert_all_with_enum_values
    Book.insert_all! [{ status: :published, isbn: "1234566", name: "Rework", author_id: 1 },
                      { status: :proposed, isbn: "1234567", name: "Remote", author_id: 2 }]
    assert_equal ["published", "proposed"], Book.where(isbn: ["1234566", "1234567"]).order(:id).pluck(:status)
  end

  def test_insert_all_on_relation
    author = Author.create!(name: "Jimmy")

    assert_difference "author.books.count", +1 do
      author.books.insert_all!([{ name: "My little book", isbn: "1974522598" }])
    end
  end

  def test_insert_all_on_relation_precedence
    author = Author.create!(name: "Jimmy")
    second_author = Author.create!(name: "Bob")

    assert_difference "author.books.count", +1 do
      author.books.insert_all!([{ name: "My little book", isbn: "1974522598", author_id: second_author.id }])
    end
  end

  def test_insert_all_resets_relation
    audit_logs = Developer.create!(name: "Alice").audit_logs.load

    assert_changes "audit_logs.loaded?", from: true, to: false do
      audit_logs.insert_all!([{ message: "event" }])
    end
  end

  def test_insert_all_create_with
    assert_difference "Book.where(format: 'X').count", +2 do
      Book.create_with(format: "X").insert_all!([ { name: "A" }, { name: "B" } ])
    end
  end

  def test_insert_all_has_many_through
    book = Book.first
    assert_raise(ArgumentError) { book.subscribers.insert_all!([ { nick: "Jimmy" } ]) }
  end

  def test_upsert_all_on_relation
    skip unless supports_insert_on_duplicate_update?

    author = Author.create!(name: "Jimmy")

    assert_difference "author.books.count", +1 do
      author.books.upsert_all([{ name: "My little book", isbn: "1974522598" }])
    end
  end

  def test_upsert_all_on_relation_precedence
    skip unless supports_insert_on_duplicate_update?

    author = Author.create!(name: "Jimmy")
    second_author = Author.create!(name: "Bob")

    assert_difference "author.books.count", +1 do
      author.books.upsert_all([{ name: "My little book", isbn: "1974522598", author_id: second_author.id }])
    end
  end

  def test_upsert_all_resets_relation
    skip unless supports_insert_on_duplicate_update?

    audit_logs = Developer.create!(name: "Alice").audit_logs.load

    assert_changes "audit_logs.loaded?", from: true, to: false do
      audit_logs.upsert_all([{ id: 1, message: "event" }])
    end
  end

  def test_upsert_all_create_with
    skip unless supports_insert_on_duplicate_update?

    assert_difference "Book.where(format: 'X').count", +2 do
      Book.create_with(format: "X").upsert_all([ { name: "A" }, { name: "B" } ])
    end
  end

  def test_upsert_all_has_many_through
    skip unless supports_insert_on_duplicate_update?

    book = Book.first
    assert_raise(ArgumentError) { book.subscribers.upsert_all([ { nick: "Jimmy" } ]) }
  end

  def test_upsert_all_updates_using_provided_sql
    skip unless supports_insert_on_duplicate_update?

    operator = current_adapter?(:SQLite3Adapter) ? "MAX" : "GREATEST"

    Book.upsert_all(
      [{ id: 1, status: 1 }, { id: 2, status: 1 }],
      on_duplicate: Arel.sql("status = #{operator}(books.status, 1)")
    )
    assert_equal "published", Book.find(1).status
    assert_equal "written", Book.find(2).status
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_upsert_all_updates_using_values_function_on_duplicate_raw_sql
      skip unless supports_insert_on_duplicate_update?

      b1 = Book.create!(name: "Name")
      b2 = Book.create!(name: nil)

      Book.upsert_all(
        [{ id: b1.id, name: "No Name" }, { id: b2.id, name: "No Name" }],
        on_duplicate: Arel.sql("name = IFNULL(name, values(name))")
      )

      b1.reload
      b2.reload

      assert_equal "Name", b1.name
      assert_equal "No Name", b2.name
    end
  end

  def test_upsert_all_updates_using_provided_sql_and_unique_by
    skip unless supports_insert_on_duplicate_update? && supports_insert_conflict_target?

    book = books(:rfr)
    assert_equal "proposed", book.status

    Book.upsert_all(
      [{ name: book.name, author_id: book.author_id }],
      unique_by: [:name, :author_id],
      on_duplicate: Arel.sql("status = 2")
    )
    assert_equal "published", book.reload.status
  end

  def test_upsert_all_with_unique_by_fails_cleanly_for_adapters_not_supporting_insert_conflict_target
    skip if supports_insert_conflict_target?

    error = assert_raises ArgumentError do
      Book.upsert_all [{ name: "Rework", author_id: 1 }], unique_by: :isbn
    end
    assert_match "#{ActiveRecord::Base.lease_connection.class} does not support :unique_by", error.message
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_insert_all_when_table_name_contains_database
      database_name = Book.connection_db_config.database
      Book.table_name = "#{database_name}.books"

      assert_nothing_raised do
        Book.insert_all! [{ name: "Rework", author_id: 1 }]
      end
    ensure
      Book.table_name = "books"
    end
  end

  def test_insert_all_with_unpersisted_records_triggers_deprecation
    skip unless supports_insert_on_duplicate_skip?

    author = Author.create!(name: "Rafael")
    author.books.build(title: "Unpersisted Book")

    assert_deprecated(ActiveRecord.deprecator) do
      author.books.insert({ title: "New Book" })
    end

    author.books.load
    assert_includes author.books.pluck(:title), "Unpersisted Book"
  end

  def test_insert_all_without_unpersisted_records_has_no_deprecation
    skip unless supports_insert_on_duplicate_skip?

    author = Author.create!(name: "Rafael")

    assert_not_deprecated(ActiveRecord.deprecator) do
      author.books.insert_all([{ title: "New Book" }])
    end
  end

  def test_insert_with_unpersisted_records_triggers_deprecation
    skip unless supports_insert_on_duplicate_skip?

    author = Author.create!(name: "Rafael")
    author.books.build(title: "Unpersisted Book")

    assert_deprecated(ActiveRecord.deprecator) do
      author.books.insert({ title: "New Book" })
    end

    author.books.load
    assert_includes author.books.pluck(:title), "Unpersisted Book"
  end

  def test_insert_without_unpersisted_records_has_no_deprecation
    skip unless supports_insert_on_duplicate_skip?

    author = Author.create!(name: "Rafael")

    assert_not_deprecated(ActiveRecord.deprecator) do
      author.books.insert({ title: "New Book" })
    end
  end

  def test_insert_all_bang_with_unpersisted_record_triggers_deprecation
    author = Author.create!(name: "Rafael")
    author.books.build(title: "Unpersisted Book")

    assert_deprecated(ActiveRecord.deprecator) do
      author.books.insert_all!([{ title: "New Book" }])
    end

    author.books.load
    assert_includes author.books.pluck(:title), "Unpersisted Book"
  end

  def test_insert_all_bang_without_unpersisted_records_has_no_deprecation
    author = Author.create!(name: "Rafael")

    assert_not_deprecated(ActiveRecord.deprecator) do
      author.books.insert_all!([{ title: "New Book" }])
    end
  end

  def test_upsert_all_with_unpersisted_record_triggers_deprecation
    skip unless supports_insert_on_duplicate_update?

    author = Author.create!(name: "Rafael")
    author.books.build(title: "Unpersisted Book")

    assert_deprecated(ActiveRecord.deprecator) do
      author.books.upsert_all([{ title: "New Book" }])
    end

    author.books.load
    assert_includes author.books.pluck(:title), "Unpersisted Book"
  end

  def test_upsert_all_without_unpersisted_records_has_no_deprecation
    skip unless supports_insert_on_duplicate_update?

    author = Author.create!(name: "Rafael")

    assert_not_deprecated(ActiveRecord.deprecator) do
      author.books.upsert_all([{ title: "New Book" }])
    end
  end

  def test_upsert_with_unpersisted_record_triggers_deprecation
    skip unless supports_insert_on_duplicate_update?

    author = Author.create!(name: "Rafael")
    author.books.build(title: "Unpersisted Book")

    assert_deprecated(ActiveRecord.deprecator) do
      author.books.upsert({ title: "New Book" })
    end

    author.books.load
    assert_includes author.books.pluck(:title), "Unpersisted Book"
  end

  def test_upsert_without_unpersisted_records_has_no_deprecation
    skip unless supports_insert_on_duplicate_update?

    author = Author.create!(name: "Rafael")

    assert_not_deprecated(ActiveRecord.deprecator) do
      author.books.upsert({ title: "New Book" })
    end
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

    def with_record_timestamps(model, value)
      original = model.record_timestamps
      model.record_timestamps = value
      yield
    ensure
      model.record_timestamps = original
    end
end
