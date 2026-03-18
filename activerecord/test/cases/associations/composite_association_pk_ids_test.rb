# frozen_string_literal: true

require "cases/helper"

# Regression test for ids_writer when the association primary key is composite
# but the target model has a scalar primary key.
#
# ThroughReflection#association_primary_key returns an array when the source
# belongs_to has primary_key: [:col1, :col2]. But CollectionAssociation#ids_writer
# checked klass.composite_primary_key? (the target model's PK) instead of
# primary_key.is_a?(Array) to decide which code path to take. When the target
# model has a scalar PK, it took the scalar branch and crashed.
class CompositeAssociationPkIdsTest < ActiveRecord::TestCase
  self.use_transactional_tests = true

  def setup
    @connection = ActiveRecord::Base.lease_connection

    @connection.create_table :_test_series, force: true do |t|
      t.string :name
    end

    @connection.create_table :_test_books, force: true do |t|
      t.integer :series_id
      t.string :title
    end

    @connection.create_table :_test_authorships, force: true do |t|
      t.integer :series_id
      t.integer :book_id
      t.integer :author_id
    end

    @connection.create_table :_test_authors, force: true do |t|
      t.string :name
    end

    Object.const_set(:TestBook, Class.new(ActiveRecord::Base) {
      self.table_name = "_test_books"
      self.primary_key = :id
    })

    Object.const_set(:TestAuthorship, Class.new(ActiveRecord::Base) {
      self.table_name = "_test_authorships"

      belongs_to :author, class_name: "TestAuthor"
      belongs_to :book,
        class_name: "TestBook",
        primary_key: [:series_id, :id],
        foreign_key: [:series_id, :book_id]
    })

    Object.const_set(:TestAuthor, Class.new(ActiveRecord::Base) {
      self.table_name = "_test_authors"

      has_many :authorships, class_name: "TestAuthorship", foreign_key: :author_id
      has_many :books, through: :authorships, class_name: "TestBook", source: :book
    })
  end

  def teardown
    %w[TestAuthor TestAuthorship TestBook].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end

    @connection.drop_table :_test_authorships, if_exists: true
    @connection.drop_table :_test_books, if_exists: true
    @connection.drop_table :_test_series, if_exists: true
    @connection.drop_table :_test_authors, if_exists: true
  end

  def test_ids_writer_with_composite_association_pk_and_scalar_model_pk
    author = TestAuthor.create!(name: "Author")
    book = TestBook.create!(series_id: 1, title: "Book 1")
    TestAuthorship.create!(author_id: author.id, series_id: book.series_id, book_id: book.id)

    # Verify: association PK is composite, model PK is scalar
    reflection = TestAuthor.reflect_on_association(:books)
    assert_equal ["series_id", "id"], reflection.association_primary_key
    assert_not TestBook.composite_primary_key?

    # ids_reader returns composite pairs — this is expected
    ids = author.book_ids
    assert_equal 1, ids.size
    assert_kind_of Array, ids.first

    # ids_writer should accept those same composite pairs back without crashing
    author.book_ids = ids
    author.reload

    assert_equal ids, author.book_ids
  end
end
