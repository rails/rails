# frozen_string_literal: true

require "cases/helper"
require "models/book"

class EnumI18nTests < ActiveRecord::TestCase
  fixtures :books

  def setup
    I18n.backend = I18n::Backend::Simple.new
    @book = books(:awdr)
  end

  def test_translated_enum
    I18n.backend.store_translations "en", activerecord: { enums: { book: { status: { published: "Already published" } } } }
    assert_equal "Already published", @book.human_enum_name("status")
  end

  def test_translated_enum_with_symbol
    I18n.backend.store_translations "en", activerecord: { enums: { book: { status: { published: "Already published" } } } }
    assert_equal "Already published", @book.human_enum_name(:status)
  end

  def test_translated_enum_default
    assert_equal "Published", @book.human_enum_name("status")
    assert_equal "English", @book.human_enum_name("language")
    assert_equal "Visible", @book.human_enum_name("author_visibility")
    assert_equal "Medium", @book.human_enum_name("difficulty")
    assert_equal "Soft", @book.human_enum_name("cover")
  end

  def test_translated_specfied_enum_value
    I18n.backend.store_translations "en", activerecord: { enums: { book: { status: { published: "Already published" } } } }
    assert_equal "Already published", Book.human_enum_name("status", "published")
  end

  def test_translated_specfied_enum_value_with_symbols
    I18n.backend.store_translations "en", activerecord: { enums: { book: { status: { published: "Already published" } } } }
    assert_equal "Already published", Book.human_enum_name(:status, :published)
  end

  def test_translated_specfied_enum_value_defalut
    assert_equal "Proposed", Book.human_enum_name("status", "proposed")
    assert_equal "Written", Book.human_enum_name("status", "written")
    assert_equal "Published", Book.human_enum_name("status", "published")
  end

  def test_translated_enum_names
    I18n.backend.store_translations "en", activerecord: { enums: { book: { status: { published: "Already published" } } } }
    assert_equal({ "proposed" => "Proposed", "written" => "Written", "published" => "Already published" }, Book.human_enum_names_hash("status"))
  end
end
