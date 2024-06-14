# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"
require "models/comment"
require "models/developer"
require "models/computer"
require "models/project"
require "models/reader"
require "models/person"
require "models/ship"

class ReadOnlyTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :posts, :comments, :developers, :projects, :developers_projects, :people, :readers

  def test_cant_save_readonly_record
    dev = Developer.find(1)
    assert_not_predicate dev, :readonly?

    dev.readonly!
    assert_predicate dev, :readonly?

    assert_nothing_raised do
      dev.name = "Luscious forbidden fruit."
      assert_not dev.save
      dev.name = "Forbidden."
    end

    e = assert_raise(ActiveRecord::ReadOnlyRecord) { dev.save  }
    assert_equal "Developer is marked as readonly", e.message

    e = assert_raise(ActiveRecord::ReadOnlyRecord) { dev.save! }
    assert_equal "Developer is marked as readonly", e.message

    e = assert_raise(ActiveRecord::ReadOnlyRecord) { dev.destroy }
    assert_equal "Developer is marked as readonly", e.message
  end

  def test_cant_touch_readonly_record
    dev = Developer.find(1)
    assert_not_predicate dev, :readonly?

    dev.readonly!
    assert_predicate dev, :readonly?

    e = assert_raise(ActiveRecord::ReadOnlyRecord) { dev.touch  }
    assert_equal "Developer is marked as readonly", e.message
  end

  def test_cant_touch_readonly_column
    person = Person.find(1)

    e = assert_raise(ActiveRecord::ActiveRecordError) { person.touch(:born_at)  }
    assert_equal "born_at is marked as readonly", e.message
  end

  def test_cant_update_column_readonly_record
    dev = Developer.find(1)
    assert_not_predicate dev, :readonly?

    dev.readonly!
    assert_predicate dev, :readonly?

    e = assert_raise(ActiveRecord::ReadOnlyRecord) { dev.update_column(:name, "New name")  }
    assert_equal "Developer is marked as readonly", e.message
  end

  def test_cant_update_columns_readonly_record
    dev = Developer.find(1)
    assert_not_predicate dev, :readonly?

    dev.readonly!
    assert_predicate dev, :readonly?

    e = assert_raise(ActiveRecord::ReadOnlyRecord) { dev.update_columns(name: "New name")  }
    assert_equal "Developer is marked as readonly", e.message
  end

  def test_find_with_readonly_option
    Developer.all.each { |d| assert_not d.readonly? }
    Developer.all.tap { |rel| assert_not rel.readonly? }
    Developer.readonly(false).each { |d| assert_not d.readonly? }
    Developer.readonly(true).each { |d| assert_predicate d, :readonly? }
    Developer.readonly.each { |d| assert_predicate d, :readonly? }
    Developer.readonly.tap { |rel| assert_predicate rel, :readonly? }
  end

  def test_find_with_joins_option_does_not_imply_readonly
    Developer.joins("  ").each { |d| assert_not d.readonly? }
    Developer.joins("  ").readonly(true).each { |d| assert_predicate d, :readonly? }

    Developer.joins(", projects").each { |d| assert_not d.readonly? }
    Developer.joins(", projects").readonly(true).each { |d| assert_predicate d, :readonly? }
  end

  def test_has_many_find_readonly
    post = Post.find(1)
    assert_not_empty post.comments
    assert_not post.comments.any?(&:readonly?)
    assert_not post.comments.to_a.any?(&:readonly?)
    assert post.comments.readonly(true).all?(&:readonly?)
  end

  def test_has_many_with_through_is_not_implicitly_marked_readonly
    assert people = Post.find(1).people
    assert_not people.any?(&:readonly?)
  end

  def test_has_many_with_through_is_not_implicitly_marked_readonly_while_finding_by_id
    assert_not_predicate posts(:welcome).people.find(1), :readonly?
  end

  def test_has_many_with_through_is_not_implicitly_marked_readonly_while_finding_first
    assert_not_predicate posts(:welcome).people.first, :readonly?
  end

  def test_has_many_with_through_is_not_implicitly_marked_readonly_while_finding_last
    assert_not_predicate posts(:welcome).people.last, :readonly?
  end

  def test_readonly_scoping
    Post.where("1=1").scoping do
      assert_not_predicate Post.find(1), :readonly?
      assert_predicate Post.readonly(true).find(1), :readonly?
      assert_not_predicate Post.readonly(false).find(1), :readonly?
    end

    Post.joins("   ").scoping do
      assert_not_predicate Post.find(1), :readonly?
      assert_predicate Post.readonly.find(1), :readonly?
      assert_not_predicate Post.readonly(false).find(1), :readonly?
    end

    Post.joins(", developers").scoping do
      assert_not_predicate Post.find(1), :readonly?
      assert_predicate Post.readonly.find(1), :readonly?
      assert_not_predicate Post.readonly(false).find(1), :readonly?
    end

    Post.readonly(true).scoping do
      assert_predicate Post.find(1), :readonly?
      assert_predicate Post.readonly.find(1), :readonly?
      assert_not_predicate Post.readonly(false).find(1), :readonly?
    end
  end

  def test_association_collection_method_missing_scoping_not_readonly
    developer = Developer.find(1)
    project   = Post.find(1)

    assert_not_predicate developer.projects.all_as_method.first, :readonly?
    assert_not_predicate developer.projects.all_as_scope.first, :readonly?

    assert_not_predicate project.comments.all_as_method.first, :readonly?
    assert_not_predicate project.comments.all_as_scope.first, :readonly?
  end
end
