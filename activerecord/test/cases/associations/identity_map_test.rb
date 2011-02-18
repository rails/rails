require "cases/helper"
require 'models/author'
require 'models/post'

if ActiveRecord::IdentityMap.enabled?
class InverseHasManyIdentityMapTest < ActiveRecord::TestCase
  fixtures :authors, :posts

  def test_parent_instance_should_be_shared_with_every_child_on_find
    m = Author.first
    is = m.posts
    is.each do |i|
      assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
      m.name = 'Bongo'
      assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
      i.author.name = 'Mungo'
      assert_equal m.name, i.author.name, "Name of man should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_eager_loaded_children
    m = Author.find(:first, :include => :posts)
    is = m.posts
    is.each do |i|
      assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
      m.name = 'Bongo'
      assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
      i.author.name = 'Mungo'
      assert_equal m.name, i.author.name, "Name of man should be the same after changes to child-owned instance"
    end

    m = Author.find(:first, :include => :posts, :order => 'posts.id')
    is = m.posts
    is.each do |i|
      assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
      m.name = 'Bongo'
      assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
      i.author.name = 'Mungo'
      assert_equal m.name, i.author.name, "Name of man should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_newly_built_child
    m = Author.first
    i = m.posts.build(:title => 'Industrial Revolution Re-enactment', :body => 'Lorem ipsum')
    assert_not_nil i.author
    assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
    i.author.name = 'Mungo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to just-built-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_block_style_built_child
    m = Author.first
    i = m.posts.build {|ii| ii.title = 'Industrial Revolution Re-enactment'; ii.body = 'Lorem ipsum'}
    assert_not_nil i.title, "Child attributes supplied to build via blocks should be populated"
    assert_not_nil i.author
    assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
    i.author.name = 'Mungo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to just-built-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_child
    m = Author.first
    i = m.posts.create(:title => 'Industrial Revolution Re-enactment', :body => 'Lorem ipsum')
    assert_not_nil i.author
    assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
    i.author.name = 'Mungo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_via_bang_method_child
    m = Author.first
    i = m.posts.create!(:title => 'Industrial Revolution Re-enactment', :body => 'Lorem ipsum')
    assert_not_nil i.author
    assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
    i.author.name = 'Mungo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_block_style_created_child
    m = Author.first
    i = m.posts.create {|ii| ii.title = 'Industrial Revolution Re-enactment'; ii.body = 'Lorem ipsum'}
    assert_not_nil i.title, "Child attributes supplied to create via blocks should be populated"
    assert_not_nil i.author
    assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
    i.author.name = 'Mungo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_poked_in_child
    m = Author.first
    i = Post.create(:title => 'Industrial Revolution Re-enactment', :body => 'Lorem ipsum')
    m.posts << i
    assert_not_nil i.author
    assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
    i.author.name = 'Mungo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_replaced_via_accessor_children
    m = Author.first
    i = Post.new(:title => 'Industrial Revolution Re-enactment', :body => 'Lorem ipsum')
    m.posts = [i]
    assert_same m, i.author
    assert_not_nil i.author
    assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
    i.author.name = 'Mungo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to replaced-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_replaced_via_method_children
    m = Author.first
    i = Post.new(:title => 'Industrial Revolution Re-enactment', :body => 'Lorem ipsum')
    m.posts = [i]
    assert_not_nil i.author
    assert_equal m.name, i.author.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to parent instance"
    i.author.name = 'Mungo'
    assert_equal m.name, i.author.name, "Name of man should be the same after changes to replaced-child-owned instance"
  end
end
end
