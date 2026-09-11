# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class UnsignedPrimaryKeysTest < ActiveRecord::AbstractMysqlTestCase
  include SchemaDumpingHelper
  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @unsigned_primary_keys = @connection.class.unsigned_primary_keys
  end

  teardown do
    @connection.class.unsigned_primary_keys = @unsigned_primary_keys
    @connection.drop_table :unsigned_authors_books, if_exists: true
    @connection.drop_table :unsigned_books, if_exists: true
    @connection.drop_table :unsigned_authors, if_exists: true
  end

  test "is disabled by default" do
    assert_equal false, @connection.class.unsigned_primary_keys
  end

  test "primary keys and references are signed by default" do
    @connection.create_table :unsigned_authors, force: true
    @connection.create_table :unsigned_books, force: true do |t|
      t.references :author
    end
    @connection.add_reference :unsigned_books, :editor

    assert_signed_bigint column(:unsigned_authors, :id)
    assert_predicate column(:unsigned_authors, :id), :auto_increment?
    assert_signed_bigint column(:unsigned_books, :author_id)
    assert_signed_bigint column(:unsigned_books, :editor_id)

    output = dump_table_schema("unsigned_authors", "unsigned_books")
    assert_match %r/create_table "unsigned_authors", charset: /, output
    assert_match %r/t\.bigint\s+"author_id"$/, output
    assert_match %r/t\.bigint\s+"editor_id"$/, output
  end

  test "primary keys are unsigned when enabled" do
    enable_unsigned_primary_keys

    @connection.create_table :unsigned_authors, force: true
    id = column(:unsigned_authors, :id)

    assert_unsigned_bigint id
    assert_predicate id, :auto_increment?
    assert_match %r/create_table "unsigned_authors", charset: /, dump_table_schema("unsigned_authors")
  end

  test "primary keys can be kept signed with unsigned: false when enabled" do
    enable_unsigned_primary_keys

    @connection.create_table :unsigned_authors, unsigned: false, force: true

    assert_signed_bigint column(:unsigned_authors, :id)
    assert_match %r/create_table "unsigned_authors", id: { type: :bigint, unsigned: false }, charset: /, dump_table_schema("unsigned_authors")

    @connection.create_table :unsigned_authors, id: { type: :bigint, unsigned: false }, force: true

    assert_signed_bigint column(:unsigned_authors, :id)
  end

  test "integer primary keys are unsigned when enabled" do
    enable_unsigned_primary_keys

    @connection.create_table :unsigned_authors, id: :integer, force: true
    id = column(:unsigned_authors, :id)

    assert_predicate id, :unsigned?
    assert_not_predicate id, :bigint?
    assert_match %r/create_table "unsigned_authors", id: { type: :integer, unsigned: true }/, dump_table_schema("unsigned_authors")

    @connection.create_table :unsigned_authors, id: :integer, unsigned: false, force: true
    id = column(:unsigned_authors, :id)

    assert_not_predicate id, :unsigned?
    assert_match %r/create_table "unsigned_authors", id: { type: :integer, unsigned: false }/, dump_table_schema("unsigned_authors")
  end

  test "integer primary keys without auto increment are unsigned when enabled" do
    enable_unsigned_primary_keys

    @connection.create_table :unsigned_authors, id: :bigint, default: nil, force: true
    id = column(:unsigned_authors, :id)

    assert_unsigned_bigint id
    assert_not_predicate id, :auto_increment?
    assert_match %r/create_table "unsigned_authors", id: { type: :bigint, unsigned: true, default: nil }/, dump_table_schema("unsigned_authors")

    @connection.create_table :unsigned_authors, id: :bigint, default: nil, unsigned: false, force: true
    id = column(:unsigned_authors, :id)

    assert_signed_bigint id
    assert_not_predicate id, :auto_increment?
    assert_match %r/create_table "unsigned_authors", id: { type: :bigint, default: nil, unsigned: false }/, dump_table_schema("unsigned_authors")
  end

  test "primary keys defined as columns are unsigned when enabled" do
    enable_unsigned_primary_keys

    @connection.create_table :unsigned_authors, id: false, force: true do |t|
      t.bigint :id, primary_key: true
    end

    assert_unsigned_bigint column(:unsigned_authors, :id)

    @connection.create_table :unsigned_authors, id: false, force: true do |t|
      t.primary_key :id, :bigint, unsigned: false
    end

    assert_signed_bigint column(:unsigned_authors, :id)
  end

  test "non-integer primary keys are not affected when enabled" do
    enable_unsigned_primary_keys

    @connection.create_table :unsigned_authors, id: :string, force: true

    assert_equal :string, column(:unsigned_authors, :id).type
    assert_match %r/create_table "unsigned_authors", id: :string, charset: /, dump_table_schema("unsigned_authors")
  end

  test "references are unsigned when enabled" do
    enable_unsigned_primary_keys

    @connection.create_table :unsigned_books, force: true do |t|
      t.references :author
      t.belongs_to :publisher, type: :integer
      t.references :series, type: :bigint
      t.references :catalog, type: "bigint"
      t.references :volume, type: :unsigned_bigint
      t.references :editor, unsigned: false
      t.references :imprint, type: :bigint, unsigned: false
      t.references :isbn, type: :string
      t.references :owner, polymorphic: true
    end

    assert_unsigned_bigint column(:unsigned_books, :author_id)
    assert_predicate column(:unsigned_books, :publisher_id), :unsigned?
    assert_not_predicate column(:unsigned_books, :publisher_id), :bigint?
    assert_unsigned_bigint column(:unsigned_books, :series_id)
    assert_unsigned_bigint column(:unsigned_books, :catalog_id)
    assert_unsigned_bigint column(:unsigned_books, :volume_id)
    assert_signed_bigint column(:unsigned_books, :editor_id)
    assert_signed_bigint column(:unsigned_books, :imprint_id)
    assert_equal :string, column(:unsigned_books, :isbn_id).type
    assert_unsigned_bigint column(:unsigned_books, :owner_id)
    assert_equal :string, column(:unsigned_books, :owner_type).type

    output = dump_table_schema("unsigned_books")
    assert_match %r/t\.bigint\s+"author_id",\s+unsigned: true$/, output
    assert_match %r/t\.integer\s+"publisher_id",\s+unsigned: true$/, output
    assert_match %r/t\.bigint\s+"series_id",\s+unsigned: true$/, output
    assert_match %r/t\.bigint\s+"editor_id"$/, output
    assert_match %r/t\.bigint\s+"imprint_id"$/, output
  end

  test "add_reference and change_table references are unsigned when enabled" do
    enable_unsigned_primary_keys

    @connection.create_table :unsigned_books, force: true
    @connection.add_reference :unsigned_books, :author
    @connection.add_belongs_to :unsigned_books, :publisher, type: :integer
    @connection.add_reference :unsigned_books, :series, type: :bigint
    @connection.add_reference :unsigned_books, :editor, unsigned: false
    @connection.change_table :unsigned_books do |t|
      t.references :reviewer
      t.belongs_to :translator, unsigned: false
    end
    @connection.change_table :unsigned_books, bulk: true do |t|
      t.references :illustrator
    end

    assert_unsigned_bigint column(:unsigned_books, :author_id)
    assert_predicate column(:unsigned_books, :publisher_id), :unsigned?
    assert_not_predicate column(:unsigned_books, :publisher_id), :bigint?
    assert_unsigned_bigint column(:unsigned_books, :series_id)
    assert_signed_bigint column(:unsigned_books, :editor_id)
    assert_unsigned_bigint column(:unsigned_books, :reviewer_id)
    assert_signed_bigint column(:unsigned_books, :translator_id)
    assert_unsigned_bigint column(:unsigned_books, :illustrator_id)
  end

  test "create_join_table columns are unsigned when enabled" do
    enable_unsigned_primary_keys

    @connection.create_join_table :unsigned_authors, :unsigned_books

    assert_unsigned_bigint column(:unsigned_authors_books, :unsigned_author_id)
    assert_unsigned_bigint column(:unsigned_authors_books, :unsigned_book_id)
  end

  test "references match the primary keys they point to so foreign keys can be added when enabled" do
    enable_unsigned_primary_keys

    @connection.create_table :unsigned_authors, force: true
    @connection.create_table :unsigned_books, force: true do |t|
      t.references :author, type: :bigint, foreign_key: { to_table: :unsigned_authors }
    end
    @connection.add_reference :unsigned_books, :editor, foreign_key: { to_table: :unsigned_authors }

    assert_equal 2, @connection.foreign_keys(:unsigned_books).size
  end

  test "schema dump spells out signed primary keys when enabled" do
    @connection.create_table :unsigned_authors, force: true
    @connection.create_table :unsigned_books, force: true do |t|
      t.references :author, foreign_key: { to_table: :unsigned_authors }
    end

    enable_unsigned_primary_keys

    output = dump_table_schema("unsigned_authors", "unsigned_books")
    assert_match %r/create_table "unsigned_authors", id: { type: :bigint, unsigned: false }, charset: /, output
    assert_match %r/create_table "unsigned_books", id: { type: :bigint, unsigned: false }, charset: /, output
    assert_match %r/t\.bigint\s+"author_id"$/, output
    assert_match %r/add_foreign_key "unsigned_books", "unsigned_authors", column: "author_id"/, output

    # Loading what was dumped recreates the signed keys, so the foreign key still matches.
    @connection.drop_table :unsigned_books
    @connection.drop_table :unsigned_authors
    @connection.create_table :unsigned_authors, id: { type: :bigint, unsigned: false }, force: :cascade
    @connection.create_table :unsigned_books, id: { type: :bigint, unsigned: false }, force: :cascade do |t|
      t.bigint :author_id
    end
    @connection.add_foreign_key :unsigned_books, :unsigned_authors, column: :author_id

    assert_signed_bigint column(:unsigned_authors, :id)
    assert_signed_bigint column(:unsigned_books, :author_id)
    assert_equal 1, @connection.foreign_keys(:unsigned_books).size
  end

  private
    def enable_unsigned_primary_keys
      @connection.class.unsigned_primary_keys = true
    end

    def column(table_name, column_name)
      @connection.columns(table_name).find { |column| column.name == column_name.to_s }
    end

    def assert_unsigned_bigint(column)
      assert_predicate column, :bigint?
      assert_predicate column, :unsigned?
    end

    def assert_signed_bigint(column)
      assert_predicate column, :bigint?
      assert_not_predicate column, :unsigned?
    end
end
