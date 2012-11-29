require "cases/helper"
require 'models/post'
require 'models/comment'
require 'models/developer'
require 'models/project'
require 'models/reader'
require 'models/person'

class ReadOnlyTest < ActiveRecord::TestCase
  fixtures :posts, :comments, :developers, :projects, :developers_projects, :people, :readers

  def test_cant_save_readonly_record
    dev = Developer.find(1)
    refute dev.readonly?

    dev.readonly!
    assert dev.readonly?

    assert_nothing_raised do
      dev.name = 'Luscious forbidden fruit.'
      refute dev.save
      dev.name = 'Forbidden.'
    end
    assert_raise(ActiveRecord::ReadOnlyRecord) { dev.save  }
    assert_raise(ActiveRecord::ReadOnlyRecord) { dev.save! }
    assert_raise(ActiveRecord::ReadOnlyRecord) { dev.destroy }
  end


  def test_find_with_readonly_option
    Developer.all.each { |d| refute d.readonly? }
    Developer.readonly(false).each { |d| refute d.readonly? }
    Developer.readonly(true).each { |d| assert d.readonly? }
    Developer.readonly.each { |d| assert d.readonly? }
  end


  def test_find_with_joins_option_implies_readonly
    # Blank joins don't count.
    Developer.joins('  ').each { |d| refute d.readonly? }
    Developer.joins('  ').readonly(false).each { |d| refute d.readonly? }

    # Others do.
    Developer.joins(', projects').each { |d| assert d.readonly? }
    Developer.joins(', projects').readonly(false).each { |d| refute d.readonly? }
  end

  def test_has_many_find_readonly
    post = Post.find(1)
    refute post.comments.empty?
    refute post.comments.any?(&:readonly?)
    refute post.comments.to_a.any?(&:readonly?)
    assert post.comments.readonly(true).all?(&:readonly?)
  end

  def test_has_many_with_through_is_not_implicitly_marked_readonly
    assert people = Post.find(1).people
    refute people.any?(&:readonly?)
  end

  def test_has_many_with_through_is_not_implicitly_marked_readonly_while_finding_by_id
    refute posts(:welcome).people.find(1).readonly?
  end

  def test_has_many_with_through_is_not_implicitly_marked_readonly_while_finding_first
    refute posts(:welcome).people.first.readonly?
  end

  def test_has_many_with_through_is_not_implicitly_marked_readonly_while_finding_last
    refute posts(:welcome).people.last.readonly?
  end

  def test_readonly_scoping
    Post.where('1=1').scoping do
      refute Post.find(1).readonly?
      assert Post.readonly(true).find(1).readonly?
      refute Post.readonly(false).find(1).readonly?
    end

    Post.joins('   ').scoping do
      refute Post.find(1).readonly?
      assert Post.readonly.find(1).readonly?
      refute Post.readonly(false).find(1).readonly?
    end

    # Oracle barfs on this because the join includes unqualified and
    # conflicting column names
    unless current_adapter?(:OracleAdapter)
      Post.joins(', developers').scoping do
        assert Post.find(1).readonly?
        assert Post.readonly.find(1).readonly?
        refute Post.readonly(false).find(1).readonly?
      end
    end

    Post.readonly(true).scoping do
      assert Post.find(1).readonly?
      assert Post.readonly.find(1).readonly?
      refute Post.readonly(false).find(1).readonly?
    end
  end

  def test_association_collection_method_missing_scoping_not_readonly
    developer = Developer.find(1)
    project   = Post.find(1)

    refute developer.projects.all_as_method.first.readonly?
    refute developer.projects.all_as_scope.first.readonly?

    refute project.comments.all_as_method.first.readonly?
    refute project.comments.all_as_scope.first.readonly?
  end
end
