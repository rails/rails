require "cases/helper"
require 'models/post'
require 'models/comment'
require 'models/developer'
require 'models/project'
require 'models/reader'
require 'models/person'

# Dummy class methods to test implicit association scoping.
def Comment.foo() find :first end
def Project.foo() find :first end


class ReadOnlyTest < ActiveRecord::TestCase
  fixtures :posts, :comments, :developers, :projects, :developers_projects

  def test_cant_save_readonly_record
    dev = Developer.find(1)
    assert !dev.readonly?

    dev.readonly!
    assert dev.readonly?

    assert_nothing_raised do
      dev.name = 'Luscious forbidden fruit.'
      assert !dev.save
      dev.name = 'Forbidden.'
    end
    assert_raise(ActiveRecord::ReadOnlyRecord) { dev.save  }
    assert_raise(ActiveRecord::ReadOnlyRecord) { dev.save! }
  end


  def test_find_with_readonly_option
    Developer.find(:all).each { |d| assert !d.readonly? }
    Developer.find(:all, :readonly => false).each { |d| assert !d.readonly? }
    Developer.find(:all, :readonly => true).each { |d| assert d.readonly? }
  end


  def test_find_with_joins_option_implies_readonly
    # Blank joins don't count.
    Developer.find(:all, :joins => '  ').each { |d| assert !d.readonly? }
    Developer.find(:all, :joins => '  ', :readonly => false).each { |d| assert !d.readonly? }

    # Others do.
    Developer.find(:all, :joins => ', projects').each { |d| assert d.readonly? }
    Developer.find(:all, :joins => ', projects', :readonly => false).each { |d| assert !d.readonly? }
  end


  def test_habtm_find_readonly
    dev = Developer.find(1)
    assert !dev.projects.empty?
    assert dev.projects.all?(&:readonly?)
    assert dev.projects.find(:all).all?(&:readonly?)
    assert dev.projects.find(:all, :readonly => true).all?(&:readonly?)
  end

  def test_has_many_find_readonly
    post = Post.find(1)
    assert !post.comments.empty?
    assert !post.comments.any?(&:readonly?)
    assert !post.comments.find(:all).any?(&:readonly?)
    assert post.comments.find(:all, :readonly => true).all?(&:readonly?)
  end

  def test_has_many_with_through_is_not_implicitly_marked_readonly
    assert people = Post.find(1).people
    assert !people.any?(&:readonly?)
  end

  def test_readonly_scoping
    Post.with_scope(:find => { :conditions => '1=1' }) do
      assert !Post.find(1).readonly?
      assert Post.find(1, :readonly => true).readonly?
      assert !Post.find(1, :readonly => false).readonly?
    end

    Post.with_scope(:find => { :joins => '   ' }) do
      assert !Post.find(1).readonly?
      assert Post.find(1, :readonly => true).readonly?
      assert !Post.find(1, :readonly => false).readonly?
    end

    # Oracle barfs on this because the join includes unqualified and
    # conflicting column names
    unless current_adapter?(:OracleAdapter)
      Post.with_scope(:find => { :joins => ', developers' }) do
        assert Post.find(1).readonly?
        assert Post.find(1, :readonly => true).readonly?
        assert !Post.find(1, :readonly => false).readonly?
      end
    end

    Post.with_scope(:find => { :readonly => true }) do
      assert Post.find(1).readonly?
      assert Post.find(1, :readonly => true).readonly?
      assert !Post.find(1, :readonly => false).readonly?
    end
  end

  def test_association_collection_method_missing_scoping_not_readonly
    assert !Developer.find(1).projects.foo.readonly?
    assert !Post.find(1).comments.foo.readonly?
  end
end
