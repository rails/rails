# frozen_string_literal: true

require "cases/helper"
require "models/admin"
require "models/admin/user"
require "models/admin/account"
require "models/author"
require "models/book"
require "models/category"
require "models/comment"
require "models/cpk/car"
require "models/developer"
require "models/essay"
require "models/pet"
require "models/post"
require "models/subscriber"
require "models/subscription"
require "models/tag"
require "models/toy"

class UniformUpdateAllTest < ActiveRecord::TestCase
  fixtures :'admin/users', :books, :comments, :cpk_cars, :developers, :posts,
    :taggings, :tags, :pets, :toys

  def setup
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
    @original_db_warnings_action = :ignore

    skip unless ActiveRecord::Base.lease_connection.supports_derived_values_table?
  end

  def teardown
    Arel::Table.engine = ActiveRecord::Base
  end

  def test_values_table_default_column_names_are_column1_column2
    table = Arel::ValuesTable.new(:data, [[1, "one"], [2, "two"]])
    sql = table.from.project(Arel.star).to_sql(ActiveRecord::Base)
    result = ActiveRecord::Base.lease_connection.execute(sql)
    fields = result.is_a?(Array) ? result[0].keys : result.fields

    assert_equal ["column1", "column2"], fields
  end

  def test_uniform_update_all
    Book.uniform_update_all [
      [{ id: 1 }, { name: "Updated Book 1" }],
      [{ id: 2 }, { name: "Updated Book 2" }]
    ]

    assert_equal "Updated Book 1", Book.find(1).name
    assert_equal "Updated Book 2", Book.find(2).name
  end

  def test_uniform_update_all_by_primary_key
    Book.uniform_update_all({
      1 => { name: "Updated Book 1" },
      2 => { name: "Updated Book 2" }
    })

    assert_equal "Updated Book 1", Book.find(1).name
    assert_equal "Updated Book 2", Book.find(2).name
  end

  def test_uniform_update_all_by_primary_key_as_array
    Book.uniform_update_all({
      [1] => { name: "Updated Book 1" },
      [2] => { name: "Updated Book 2" }
    })

    assert_equal "Updated Book 1", Book.find(1).name
    assert_equal "Updated Book 2", Book.find(2).name
  end

  def test_uniform_update_all_without_conditions
    assert_raises(IndexError) do
      Book.uniform_update_all({ [] => { name: "Updated Book 1" } })
    end
    assert_raises(ArgumentError) do
      Book.uniform_update_all [[{}, { name: "Updated Book 1" }]]
    end
  end

  def test_uniform_update_all_without_values
    assert_raises(ArgumentError) do
      Book.uniform_update_all({ 1 => {} })
    end
    assert_raises(ArgumentError) do
      Book.uniform_update_all [[{ id: 1 }, {}]]
    end
  end

  def test_uniform_update_all_by_composite_primary_key
    Cpk::Car.uniform_update_all({
      ["Toyota", "Camry"] => { year: 2001 },
      ["Honda", "Civic"]  => { year: 2002 },
      ["Ford", "Civic"]   => { year: 2003 },
      ["Toyota", "Prius"] => { year: 2004 }
    })

    assert_equal 2001, Cpk::Car.find(["Toyota", "Camry"]).year
    assert_equal 2002, Cpk::Car.find(["Honda", "Civic"]).year
    assert_equal 1964, Cpk::Car.find(["Ford", "Mustang"]).year
  end

  def test_uniform_update_all_with_multiple_conditions
    Cpk::Car.uniform_update_all [
      [{ make: "Toyota", model: "Camry" }, { year: 2001 }],
      [{ make: "Honda", model: "Civic" },  { year: 2002 }],
      [{ make: "Ford", model: "Civic" },   { year: 2003 }],
      [{ make: "Toyota", model: "Prius" }, { year: 2004 }]
    ]

    assert_equal 2001, Cpk::Car.find(["Toyota", "Camry"]).year
    assert_equal 2002, Cpk::Car.find(["Honda", "Civic"]).year
    assert_equal 1964, Cpk::Car.find(["Ford", "Mustang"]).year
  end

  def test_uniform_update_all_performs_a_single_update
    affected_rows = Cpk::Car.uniform_update_all({
      ["Toyota", "Camry"] => { make: "Nissan", model: "Altima" },
      ["Nissan", "Altima"] => { make: "Chevy", model: "Corvette" }
    })

    # if the updates were "chained" the result would be Chevy Corvette
    car = Cpk::Car.find_by!(year: 1982)
    assert_equal 1, affected_rows
    assert_equal ["Nissan", "Altima"], [car.make, car.model]
  end

  def test_uniform_update_all_with_empty_updates
    assert_no_queries do
      assert_equal 0, Book.uniform_update_all([])
      assert_equal 0, Book.uniform_update_all({})
    end
  end

  def test_uniform_update_all_with_unknown_attribute_in_conditions
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.uniform_update_all [[{ invalid_column: "David" }, { status: :written }]]
    end
  end

  def test_uniform_update_all_with_unknown_attribute_in_values
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.uniform_update_all [[{ id: 1 }, { invalid_column: "Invalid" }]]
    end
  end

  def test_uniform_update_all_cannot_reference_joined_tables_in_conditions
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.joins(:author).uniform_update_all [[{ "author.nick": "David" }, { status: :written }]]
    end
  end

  def test_uniform_update_all_with_aliased_attributes
    Book.uniform_update_all [
      [{ id: 1 }, { title: "Updated Book 1" }],
      [{ id: 2 }, { title: "Updated Book 2" }]
    ]

    assert_equal "Updated Book 1", Book.find(1).name
    assert_equal "Updated Book 2", Book.find(2).name
  end

  def test_uniform_update_all_returns_number_of_rows_affected_across_all_value_rows
    affected_rows = Comment.uniform_update_all [
      [{ post_id: 1 }, { body: "A" }],
      [{ post_id: 2 }, { body: "B" }],
      [{ post_id: 4 }, { body: "C" }]
    ]

    comments = Comment.where(post_id: [1, 2, 4]).order(:post_id).group(:post_id, :body).pluck(:post_id, :body, Arel.star.count)
    assert_equal 8, affected_rows
    assert_equal [[1, "A", 2], [2, "B", 1], [4, "C", 5]], comments
    assert_equal "go wild", Comment.find(11).body
  end

  def test_uniform_update_all_with_duplicate_keys_does_not_error
    Book.uniform_update_all [
      [{ id: 1 }, { name: "Reword" }],
      [{ id: 1 }, { name: "Peopleware" }]
    ]

    assert_includes ["Reword", "Peopleware"], Book.find(1).name
  end

  def test_uniform_update_all_with_no_hits_does_not_error
    affected_rows = Book.uniform_update_all [
      [{ id: 1234 }, { name: "Reword" }],
      [{ id: 4567 }, { name: "Peopleware" }]
    ]

    assert_equal 0, affected_rows
  end

  def test_uniform_update_all_conditions_are_and_combined
    Comment.uniform_update_all [
      [{ post_id: 4, type: "Comment" },        { body: "A" }],
      [{ post_id: 4, type: "SpecialComment" }, { body: "B" }],
      [{ post_id: 5, type: "SpecialComment" }, { body: "C" }]
    ]

    comments = Comment.where(body: ["A", "B", "C"]).pluck(:id, :body).sort
    assert_equal [[6, "B"], [7, "B"], [8, "A"], [10, "C"]], comments
  end

  def test_uniform_update_all_supports_typecasting_for_rails_enums_and_booleans
    Book.uniform_update_all({
      1 => { cover: :hard,  status: :proposed,  boolean_status: :disabled,  author_id: "2" },
      2 => { cover: "soft", status: :published, boolean_status: :enabled,   author_id: nil }
    })

    books = Book.where(id: 1..2).order(:id).pluck(:cover, :status, :boolean_status, :author_id)
    assert_equal ["hard", "proposed", "disabled", 2], books[0]
    assert_equal ["soft", "published", "enabled", nil], books[1]
  end

  def test_uniform_update_all_supports_typecasting_for_jsons
    skip unless ActiveRecord::Base.connection.supports_json?

    Admin::User.uniform_update_all [
      [{ name: "David" }, { json_options: { color: "blue" } }],
      [{ name: "Jamis" }, { json_options: { "width" => 1440 } }]
    ]

    assert_equal({ "color" => "blue" }, Admin::User.find_by(name: "David").json_options)
    assert_equal({ "width" => 1440 }, Admin::User.find_by(name: "Jamis").json_options)
  end

  def test_uniform_update_all_does_not_support_referential_arel_sql_in_conditions
    assert_raises(ActiveRecord::StatementInvalid) do
      Comment.uniform_update_all [[{ parent_id: Arel.sql("comments.post_id") }, { body: "Root comment" }]]
    end
  end

  def test_uniform_update_all_does_not_support_referential_arel_sql_in_values
    assert_raises(ActiveRecord::StatementInvalid) do
      Book.uniform_update_all [[{ name: "Jamis" }, { name: Arel.sql("UPPER(name)") }]]
    end
  end

  def test_uniform_update_all_supports_non_referential_arel_sql_in_conditions
    Comment.uniform_update_all [[{ id: Arel.sql("(SELECT id FROM books ORDER BY id ASC LIMIT 1)") }, { body: "First comment" }]]
    assert_equal "First comment", Comment.find(1).body
  end

  def test_uniform_update_all_supports_non_referential_arel_sql_in_values
    Comment.uniform_update_all [[{ id: 1 }, { body: Arel.sql("(SELECT name FROM books WHERE id = 1)") }]]
    assert_equal "Agile Web Development with Rails", Comment.find(1).body
  end

  def test_uniform_update_all_timestamp_updates_are_wrapped_in_parentheses
    assert_queries_match(/ = \(CASE/) do
      Book.uniform_update_all({ 1 => { name: "Updated Book 1", status: :proposed } })
    end
  end

  def test_uniform_update_all_large_input
    Book.delete_all
    Book.insert_all! (1..1001).map { |id| { id: id, name: Random.hex, status: %i[proposed written published].sample } }
    names = Array.new(1001) { Random.hex }
    Book.uniform_update_all((1..1001).zip(names.map { |name| { name: name, status: %i[proposed written published].sample } }).to_h)

    assert_equal names[0...10], Book.order(:id).limit(10).pluck(:name)
  end

  def test_uniform_update_all_does_not_touch_updated_at_when_values_do_not_change
    created_at = Time.now.utc - 8.years
    updated_at = Time.now.utc - 5.years
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), created_at: created_at, updated_at: updated_at }]
    Book.uniform_update_all({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1) } })

    assert_in_delta updated_at, Book.find(101).updated_at, 1
  end

  def test_uniform_update_all_touches_updated_at_and_updated_on_and_not_created_at_when_values_change
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), created_at: 8.years.ago, updated_at: 5.years.ago, updated_on: 5.years.ago }]
    Book.uniform_update_all({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } })

    book = Book.find(101)
    assert_equal 8.years.ago.year, book.created_at.year
    assert_equal Time.now.utc.year, book.updated_at.year
    assert_equal Time.now.utc.year, book.updated_on.year
  end

  def test_uniform_update_all_respects_updated_at_precision_when_touched_implicitly
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]

    # A single update can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.uniform_update_all({ 101 => { name: "Out of the Silent Planet (Edition #{i})" } })
      Book.find(101).updated_at.usec > 0
    end

    assert has_subsecond_precision, "updated_at should have sub-second precision"
  end

  def test_uniform_update_all_respects_updated_at_precision_when_touched_explicitly
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]

    # A single update can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.uniform_update_all({ 101 => { name: "Out of the Silent Planet (Edition #{i})", updated_at: Time.now.utc, updated_on: Time.now.utc } })
      Book.find(101).updated_at.usec > 0 && Book.find(101).updated_on == Time.now.to_date
    end

    assert has_subsecond_precision, "updated_at should have sub-second precision"
  end

  def test_uniform_update_all_uses_given_updated_at_over_implicit_updated_at
    updated_at = Time.now.utc - 1.year
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago }]
    Book.uniform_update_all({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_at: updated_at } })

    assert_in_delta updated_at, Book.find(101).updated_at, 1
  end

  def test_uniform_update_all_uses_given_updated_on_over_implicit_updated_on
    updated_on = Time.now.utc.to_date - 30
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_on: 5.years.ago }]
    Book.uniform_update_all({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_on: updated_on } })

    assert_equal updated_on, Book.find(101).updated_on
  end

  def test_uniform_update_all_does_not_implicitly_set_timestamps_when_model_record_timestamps_is_true_but_overridden
    with_record_timestamps(Book, true) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.uniform_update_all({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: false)

      assert_in_delta 5.years.ago.year, Book.find(101).updated_at.year
      assert_in_delta 5.years.ago.year, Book.find(101).updated_on.year
    end
  end

  def test_uniform_update_all_does_not_implicitly_set_timestamps_when_model_record_timestamps_is_false
    with_record_timestamps(Book, false) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.uniform_update_all({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } })

      assert_in_delta 5.years.ago.year, Book.find(101).updated_at.year
      assert_in_delta 5.years.ago.year, Book.find(101).updated_on.year
    end
  end

  def test_uniform_update_all_implicitly_sets_timestamps_when_model_record_timestamps_is_false_but_overridden
    with_record_timestamps(Book, false) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.uniform_update_all({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: true)

      assert_in_delta Time.now.utc, Book.find(101).updated_at, 1
      assert_equal Time.now.utc.to_date, Book.find(101).updated_on, 1
    end
  end

  def test_uniform_update_all_resets_relation
    audit_logs = Developer.create!(name: "Alice").audit_logs.load

    assert_changes "audit_logs.loaded?", from: true, to: false do
      audit_logs.uniform_update_all({ 1 => { message: "event" } })
    end
  end

  def test_uniform_update_all_does_not_reset_relation_if_updates_is_empty
    audit_logs = Developer.create!(name: "Alice").audit_logs.load

    assert_no_changes "audit_logs.loaded?" do
      audit_logs.uniform_update_all({})
    end
  end

  def test_uniform_update_all_on_has_many_relation
    author = Author.create!(id: 123, name: "Jimmy")
    author.books.insert_all! [
      { id: 10, name: "Apple 1", status: :proposed },
      { id: 11, name: "Apple 2", status: :written },
      { id: 12, name: "Apple 3", status: :published }
    ]

    affected_rows = author.books.uniform_update_all [
      [{ status: :proposed }, { name: "Banana 1" }],
      [{ status: :written }, { name: "Banana 2" }]
    ]
    assert_equal 2, affected_rows
    assert_equal ["Ruby for Rails", "proposed"], Book.find(2).values_at(:name, :status)
    assert_equal ["Banana 1", "Banana 2", "Apple 3"], author.books.sort_by(&:id).map(&:name)
  end

  def test_uniform_update_all_with_group_by
    minimum_comments_count = 2
    good_post = Post.joins(:comments).group("posts.id").having("count(comments.id) < #{minimum_comments_count}").first.id
    bad_post = Post.joins(:comments).group("posts.id").having("count(comments.id) >= #{minimum_comments_count}").first.id

    assert_raises(NotImplementedError) do
      Post.most_commented(minimum_comments_count).uniform_update_all({
        good_post => { title: "ig" },
        bad_post => { title: "ig" }
      })
    end
    # assert_equal "ig", Post.find(good_post).title
    # assert_not_equal "ig", Post.find(bad_post).title
  end

  def test_uniform_update_all_with_order_limit_offset
    assert_raises(NotImplementedError) do
      Post.where(id: 1..6).order(id: :desc).limit(2).offset(2).uniform_update_all([
        [{ author_id: 0 }], { body: "ig0" },
        [{ author_id: 1 }], { body: "ig1" }
      ])
    end
    # assert_equal "ig0", Post.find(3).body
    # assert_equal "ig1", Post.find(4).body
    # assert_equal "hello", Post.find(5).body
  end

  def test_uniform_update_all_with_nil_primary_key
    affected_rows = Book.uniform_update_all [
      [{ id: 4 }, { name: "Reword" }],
      [{ id: nil }, { name: "Peopleware" }]
    ]

    assert_equal 1, affected_rows
    assert_not_includes Book.pluck(:name), "Peopleware"
  end

  def test_uniform_update_all_with_nil_composite_primary_key
    affected_rows = Cpk::Car.uniform_update_all [
      [{ make: "Toyota", model: "Camry" }, { year: 1024 }],
      [{ make: "Honda",  model: nil },     { year: 1025 }]
    ]

    assert_equal 1, affected_rows
    assert_not_includes Cpk::Car.pluck(:year), 1025
  end

  def test_uniform_update_all_with_sti_can_override_sti_type
    Category.delete_all
    Category.insert_all! [
      { id: 1, name: "First", type: "SpecialCategory" },
      { id: 2, name: "Second", type: "SpecialCategory" },
      { id: 3, name: "Third", type: "Category" }
    ]
    SpecialCategory.uniform_update_all({
      1 => { name: "1st", type: "SpecialCategory" },
      2 => { name: "2nd", type: "Category" },
      3 => { name: "3rd", type: "SpecialCategory" }
    })

    assert_equal ["1st", "2nd", "Third"], Category.order(:id).pluck(:name)
    assert_equal ["SpecialCategory", "Category", "Category"], Category.order(:id).pluck(:type)
  end

  def test_uniform_update_all_logs_message_including_model_name
    capture_log_output do |output|
      Book.uniform_update_all({
        1 => { name: "Updated Book 1" },
        2 => { name: "Updated Book 2" }
      })
      assert_match "Book Uniform Update All", output.string
    end
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_uniform_update_all_with_left_joins
      pets = Pet.left_joins(:toys).where(toys: { name: ["Bone", nil] })

      assert_equal true, pets.exists?
      assert_equal 2, pets.uniform_update_all({
        1 => { name: "Rex" },
        2 => { name: "Rex" },
        3 => { name: "Rex" }
      })
    end

    def test_uniform_update_all_with_left_outer_joins
      pets = Pet.left_outer_joins(:toys).where(toys: { name: ["Bone", nil] })

      assert_equal true, pets.exists?
      assert_equal 2, pets.uniform_update_all({
        1 => { name: "Rex" },
        2 => { name: "Rex" },
        3 => { name: "Rex" }
      })
    end

    def test_uniform_update_all_with_includes
      pets = Pet.includes(:toys).where(toys: { name: "Bone" })

      assert_equal true, pets.exists?
      assert_equal 1, pets.uniform_update_all({
        1 => { name: "Rex" },
        2 => { name: "Rex" }
      })
    end

    def test_uniform_update_all_with_scope
      tag = Tag.first # posts: [1, 2]
      Post.tagged_with(tag.id).uniform_update_all({
        1 => { title: "first" },
        2 => { title: "second" }
      })

      posts = Post.tagged_with(tag.id).all.to_a.sort_by(&:id)
      assert_operator posts.length, :>, 0
      assert_equal "first", posts[0].title
      assert_equal "second", posts[1].title
    end

    def test_uniform_update_all_when_table_name_contains_database
      database_name = Book.connection_db_config.database
      Book.table_name = "#{database_name}.books"

      assert_nothing_raised do
        Book.uniform_update_all [[{ id: 1 }, { name: "Rework" }]]
      end
    ensure
      Book.table_name = "books"
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
