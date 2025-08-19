# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/computer"
require "models/book"
require "models/author"

class SelectedColumnsTest < ActiveRecord::TestCase
  fixtures :developers, :computers, :authors, :books
  test "limits visible columns" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(Developer, [:id, :name]) do
      reloaded = Developer.find(developers(:david).id)
      assert_respond_to reloaded, :id
      assert_respond_to reloaded, :name
      assert_not_respond_to reloaded, :salary

      assert_includes Developer.attribute_names, "id"
      assert_includes Developer.attribute_names, "name"
      assert_not_includes Developer.attribute_names, "salary"
    end

    assert_includes Developer.attribute_names, "salary"
  end

  test "works with multiple models" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(
      Developer: [:id, :name],
      Computer: [:id, :system]
    ) do
      assert_includes Developer.attribute_names, "id"
      assert_includes Developer.attribute_names, "name"
      assert_not_includes Developer.attribute_names, "salary"

      assert_includes Computer.attribute_names, "id"
      assert_includes Computer.attribute_names, "system"
      assert_not_includes Computer.attribute_names, "developer"
    end

    assert_includes Developer.attribute_names, "salary"
    assert_includes Computer.attribute_names, "developer"
  end

  test "supports nested contexts" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(Developer: [:id, :name, :salary]) do
      assert_includes Developer.attribute_names, "id"
      assert_includes Developer.attribute_names, "name"
      assert_includes Developer.attribute_names, "salary"

      ActiveRecord::SelectedColumns.with_selected_columns_for(Developer: [:id, :name]) do
        assert_includes Developer.attribute_names, "id"
        assert_includes Developer.attribute_names, "name"
        assert_not_includes Developer.attribute_names, "salary"
      end

      assert_includes Developer.attribute_names, "id"
      assert_includes Developer.attribute_names, "name"
      assert_includes Developer.attribute_names, "salary"
    end
  end

  test "handles string model names" do
    ActiveRecord::SelectedColumns.with_selected_columns_for("Developer" => [:id, :name]) do
      assert_includes Developer.attribute_names, "id"
      assert_includes Developer.attribute_names, "name"
      assert_not_includes Developer.attribute_names, "salary"
    end
  end

  test "handles symbol column names" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(Developer, [:id, :name]) do
      assert_includes Developer.attribute_names, "id"
      assert_includes Developer.attribute_names, "name"
      assert_not_includes Developer.attribute_names, "salary"
    end
  end

  test "raises error for unknown columns" do
    error = assert_raises(ArgumentError) do
      ActiveRecord::SelectedColumns.with_selected_columns_for(Developer: [:id, :nonexistent]) do
      end
    end
    assert_match(/unknown columns for Developer: nonexistent/, error.message)
  end

  test "raises error for invalid model" do
    error = assert_raises(ArgumentError) do
      ActiveRecord::SelectedColumns.with_selected_columns_for("String", ["name"]) do
      end
    end
    assert_match(/does not resolve to an ActiveRecord model/, error.message)
  end

  test "raises error without block" do
    error = assert_raises(ArgumentError) do
      ActiveRecord::SelectedColumns.with_selected_columns_for(Developer: [:id])
    end
    assert_match(/block required/, error.message)
  end

  test "restores state even on exception" do
    original_columns = Developer.attribute_names.dup

    begin
      ActiveRecord::SelectedColumns.with_selected_columns_for(Developer, [:id, :name]) do
        assert_not_includes Developer.attribute_names, "salary"
        raise "test exception"
      end
    rescue RuntimeError => e
      assert_equal "test exception", e.message
    end

    assert_equal original_columns.sort, Developer.attribute_names.sort
  end

  test "is thread-safe" do
    results = {}
    threads = []

    threads << Thread.new do
      ActiveRecord::SelectedColumns.with_selected_columns_for(Developer, [:id, :name]) do
        results[:thread1] = {
          has_id: Developer.attribute_names.include?("id"),
          has_name: Developer.attribute_names.include?("name"),
          has_salary: Developer.attribute_names.include?("salary"),
          thread_id: Thread.current.object_id
        }
        sleep(0.1)
      end
    end

    threads << Thread.new do
      ActiveRecord::SelectedColumns.with_selected_columns_for(Developer, [:id, :salary]) do
        sleep(0.05)
        results[:thread2] = {
          has_id: Developer.attribute_names.include?("id"),
          has_name: Developer.attribute_names.include?("name"),
          has_salary: Developer.attribute_names.include?("salary"),
          thread_id: Thread.current.object_id
        }
      end
    end

    threads << Thread.new do
      sleep(0.03)
      results[:thread3] = {
        has_id: Developer.attribute_names.include?("id"),
        has_name: Developer.attribute_names.include?("name"),
        has_salary: Developer.attribute_names.include?("salary"),
        thread_id: Thread.current.object_id
      }
    end

    threads.each(&:join)

    assert results[:thread1][:has_id]
    assert results[:thread1][:has_name]
    assert_not results[:thread1][:has_salary]

    assert results[:thread2][:has_id]
    assert_not results[:thread2][:has_name]
    assert results[:thread2][:has_salary]

    assert results[:thread3][:has_id]
    assert results[:thread3][:has_name]
    assert results[:thread3][:has_salary]

    assert_not_equal results[:thread1][:thread_id], results[:thread2][:thread_id]
    assert_not_equal results[:thread1][:thread_id], results[:thread3][:thread_id]
    assert_not_equal results[:thread2][:thread_id], results[:thread3][:thread_id]

    assert Developer.attribute_names.include?("salary")
    assert Developer.attribute_names.include?("name")
  end

  test "works with empty column list" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(Developer, []) do
      assert Developer.attribute_names.length >= 1

      assert_includes Developer.attribute_names, "legacy_created_at"
      assert_includes Developer.attribute_names, "legacy_updated_at"
      assert_includes Developer.attribute_names, "legacy_created_on"
      assert_includes Developer.attribute_names, "legacy_updated_on"

      assert_not_includes Developer.attribute_names, "salary"
      assert_not_includes Developer.attribute_names, "firm_id"
      assert_not_includes Developer.attribute_names, "mentor_id"
    end
  end

  test "preserves existing ignored columns" do
    original_ignored = Developer.ignored_columns.dup
    Developer.ignored_columns = ["salary"]

    begin
      ActiveRecord::SelectedColumns.with_selected_columns_for(Developer, [:id, :name]) do
        assert_includes Developer.attribute_names, "id"
        assert_includes Developer.attribute_names, "name"
        assert_not_includes Developer.attribute_names, "salary"
      end

      assert_equal ["salary"], Developer.ignored_columns
    ensure
      Developer.ignored_columns = original_ignored
    end
  end

  if ActiveRecord::Base.method_defined?(:defined_enums)
    test "automatically includes enum columns" do
      ActiveRecord::SelectedColumns.with_selected_columns_for(Book, [:id, :name]) do
        assert_includes Book.attribute_names, "id"
        assert_includes Book.attribute_names, "name"

        Book.defined_enums.keys.each do |enum_column|
          assert_includes Book.attribute_names, enum_column,
            "Enum column '#{enum_column}' should be automatically included"
        end

        assert_not_includes Book.attribute_names, "author_id"
        assert_not_includes Book.attribute_names, "isbn"
      end

      assert_includes Book.attribute_names, "author_id"
      assert_includes Book.attribute_names, "isbn"
    end
  end

  test "works with preload" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(Book, [:id, :name]) do
      authors_with_books = Author.preload(:books).where(id: authors(:david).id)
      loaded_author = authors_with_books.first

      loaded_author.books.each do |book|
        assert_respond_to book, :id
        assert_respond_to book, :name
        assert_not_respond_to book, :isbn

        assert_includes book.class.attribute_names, "id"
        assert_includes book.class.attribute_names, "name"
        assert_not_includes book.class.attribute_names, "isbn"
      end
    end

    assert_includes Book.attribute_names, "isbn"
  end

  test "works with joins" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(Book, [:id, :name]) do
      books_with_authors = Book.joins(:author).where(authors: { id: authors(:david).id })

      books_with_authors.each do |joined_book|
        assert_respond_to joined_book, :id
        assert_respond_to joined_book, :name
        assert_not_respond_to joined_book, :isbn

        assert_includes Book.attribute_names, "id"
        assert_includes Book.attribute_names, "name"
        assert_not_includes Book.attribute_names, "isbn"
      end
    end

    assert_includes Book.attribute_names, "isbn"
  end

  test "works with includes" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(Book, [:id, :name]) do
      authors_with_books = Author.includes(:books).where(id: authors(:david).id)
      loaded_author = authors_with_books.first

      loaded_author.books.each do |book|
        assert_respond_to book, :id
        assert_respond_to book, :name
        assert_not_respond_to book, :isbn

        assert_includes book.class.attribute_names, "id"
        assert_includes book.class.attribute_names, "name"
        assert_not_includes book.class.attribute_names, "isbn"
      end

      direct_books = Book.where(author: authors(:david))
      direct_books.each do |book|
        assert_respond_to book, :id
        assert_respond_to book, :name
        assert_not_respond_to book, :isbn
      end
    end

    assert_includes Book.attribute_names, "isbn"
  end

  test "works with multiple models in associations" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(
      Author: [:id, :name],
      Book: [:id, :name]
    ) do
      authors_with_books = Author.includes(:books).where(id: authors(:david).id)
      loaded_author = authors_with_books.first

      assert_respond_to loaded_author, :id
      assert_respond_to loaded_author, :name
      assert_includes Author.attribute_names, "id"
      assert_includes Author.attribute_names, "name"

      loaded_author.books.each do |book|
        assert_respond_to book, :id
        assert_respond_to book, :name
        assert_not_respond_to book, :isbn

        assert_includes Book.attribute_names, "id"
        assert_includes Book.attribute_names, "name"
        assert_not_includes Book.attribute_names, "isbn"
      end
    end

    assert_includes Book.attribute_names, "isbn"
  end

  test "ensures id columns are always available for associations" do
    ActiveRecord::SelectedColumns.with_selected_columns_for(Book, [:name]) do
      assert_includes Book.attribute_names, "id"

      authors_with_books = Author.includes(:books).where(id: authors(:david).id)
      loaded_author = authors_with_books.first

      assert_operator loaded_author.books.size, :>=, 1
      book = loaded_author.books.first

      assert_respond_to book, :id
      assert_respond_to book, :name
      assert_not_respond_to book, :isbn
    end
  end
end
