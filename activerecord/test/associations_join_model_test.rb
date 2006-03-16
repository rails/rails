require 'abstract_unit'
require 'fixtures/tag'
require 'fixtures/tagging'
require 'fixtures/post'
require 'fixtures/comment'
require 'fixtures/author'
require 'fixtures/category'
require 'fixtures/categorization'

class AssociationsJoinModelTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false
  fixtures :posts, :authors, :categories, :categorizations, :comments, :tags, :taggings

  def test_has_many
    assert_equal categories(:general), authors(:david).categories.first
  end
  
  def test_has_many_inherited
    assert_equal categories(:sti_test), authors(:mary).categories.first
  end

  def test_inherited_has_many
    assert_equal authors(:mary), categories(:sti_test).authors.first
  end
  
  def test_polymorphic_has_many
    assert_equal taggings(:welcome_general), posts(:welcome).taggings.first
  end
  
  def test_polymorphic_has_one
    assert_equal taggings(:welcome_general), posts(:welcome).tagging
  end

  def test_polymorphic_belongs_to
    assert_equal posts(:welcome), posts(:welcome).taggings.first.taggable
  end

  def test_polymorphic_has_many_going_through_join_model
    assert_equal tags(:general), posts(:welcome).tags.first
  end

  def test_polymorphic_has_many_create_model_with_inheritance_and_custom_base_class
    post = SubStiPost.create :title => 'SubStiPost', :body => 'SubStiPost body'
    assert_instance_of SubStiPost, post
    
    tagging = tags(:misc).taggings.create(:taggable => post)
    assert_equal "SubStiPost", tagging.taggable_type
  end

  def test_polymorphic_has_many_going_through_join_model_with_inheritance
    assert_equal tags(:general), posts(:thinking).tags.first
  end
  
  def test_polymorphic_has_many_create_model_with_inheritance
    post = posts(:thinking)
    assert_instance_of SpecialPost, post
    
    tagging = tags(:misc).taggings.create(:taggable => post)
    assert_equal "Post", tagging.taggable_type
  end

  def test_polymorphic_has_one_create_model_with_inheritance
    tagging = tags(:misc).create_tagging(:taggable => posts(:thinking))
    assert_equal "Post", tagging.taggable_type
  end

  def test_set_polymorphic_has_many
    tagging = tags(:misc).taggings.create
    posts(:thinking).taggings << tagging
    assert_equal "Post", tagging.taggable_type
  end

  def test_set_polymorphic_has_one
    tagging = tags(:misc).taggings.create
    posts(:thinking).tagging = tagging
    assert_equal "Post", tagging.taggable_type
  end

  def test_create_polymorphic_has_many_with_scope
    old_count = posts(:welcome).taggings.count
    tagging = posts(:welcome).taggings.create(:tag => tags(:misc))
    assert_equal "Post", tagging.taggable_type
    assert_equal old_count+1, posts(:welcome).taggings.count
  end

  def test_create_polymorphic_has_one_with_scope
    old_count = Tagging.count
    tagging = posts(:welcome).tagging.create(:tag => tags(:misc))
    assert_equal "Post", tagging.taggable_type
    assert_equal old_count+1, Tagging.count
  end

  def test_delete_polymorphic_has_many_with_delete_all
    assert_equal 1, posts(:welcome).taggings.count
    posts(:welcome).taggings.first.update_attribute :taggable_type, 'PostWithHasManyDeleteAll'
    post = find_post_with_dependency(1, :has_many, :taggings, :delete_all)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count-1, Tagging.count
    assert_equal 0, posts(:welcome).taggings.count
  end

  def test_delete_polymorphic_has_many_with_destroy
    assert_equal 1, posts(:welcome).taggings.count
    posts(:welcome).taggings.first.update_attribute :taggable_type, 'PostWithHasManyDestroy'
    post = find_post_with_dependency(1, :has_many, :taggings, :destroy)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count-1, Tagging.count
    assert_equal 0, posts(:welcome).taggings.count
  end

  def test_delete_polymorphic_has_many_with_nullify
    assert_equal 1, posts(:welcome).taggings.count
    posts(:welcome).taggings.first.update_attribute :taggable_type, 'PostWithHasManyNullify'
    post = find_post_with_dependency(1, :has_many, :taggings, :nullify)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count, Tagging.count
    assert_equal 0, posts(:welcome).taggings.count
  end

  def test_delete_polymorphic_has_one_with_destroy
    assert posts(:welcome).tagging
    posts(:welcome).tagging.update_attribute :taggable_type, 'PostWithHasOneDestroy'
    post = find_post_with_dependency(1, :has_one, :tagging, :destroy)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count-1, Tagging.count
    assert_nil posts(:welcome).tagging(true)
  end

  def test_delete_polymorphic_has_one_with_nullify
    assert posts(:welcome).tagging
    posts(:welcome).tagging.update_attribute :taggable_type, 'PostWithHasOneNullify'
    post = find_post_with_dependency(1, :has_one, :tagging, :nullify)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count, Tagging.count
    assert_nil posts(:welcome).tagging(true)
  end

  def test_has_many_with_piggyback
    assert_equal "2", categories(:sti_test).authors.first.post_id.to_s
  end

  def test_include_has_many_through
    posts              = Post.find(:all, :order => 'posts.id')
    posts_with_authors = Post.find(:all, :include => :authors, :order => 'posts.id')
    assert_equal posts.length, posts_with_authors.length
    posts.length.times do |i|
      assert_equal posts[i].authors.length, assert_no_queries { posts_with_authors[i].authors.length }
    end
  end

  def test_include_polymorphic_has_many_through
    posts           = Post.find(:all, :order => 'posts.id')
    posts_with_tags = Post.find(:all, :include => :tags, :order => 'posts.id')
    assert_equal posts.length, posts_with_tags.length
    posts.length.times do |i|
      assert_equal posts[i].tags.length, assert_no_queries { posts_with_tags[i].tags.length }
    end
  end

  def test_include_polymorphic_has_many
    posts               = Post.find(:all, :order => 'posts.id')
    posts_with_taggings = Post.find(:all, :include => :taggings, :order => 'posts.id')
    assert_equal posts.length, posts_with_taggings.length
    posts.length.times do |i|
      assert_equal posts[i].taggings.length, assert_no_queries { posts_with_taggings[i].taggings.length }
    end
  end

  def test_has_many_find_all
    assert_equal [categories(:general)], authors(:david).categories.find(:all)
  end
  
  def test_has_many_find_first
    assert_equal categories(:general), authors(:david).categories.find(:first)
  end
  
  def test_has_many_find_conditions
    assert_equal categories(:general), authors(:david).categories.find(:first, :conditions => "categories.name = 'General'")
    assert_equal nil, authors(:david).categories.find(:first, :conditions => "categories.name = 'Technology'")
  end
  
  def test_has_many_class_methods_called_by_method_missing
    assert_equal categories(:general), authors(:david).categories.find_all_by_name('General').first
#    assert_equal nil, authors(:david).categories.find_by_name('Technology')
  end

  def test_has_many_going_through_join_model_with_custom_foreign_key
    assert_equal [], posts(:thinking).authors
    assert_equal [authors(:mary)], posts(:authorless).authors
  end

  def test_belongs_to_polymorphic_with_counter_cache
    assert_equal 0, posts(:welcome)[:taggings_count]
    tagging = posts(:welcome).taggings.create(:tag => tags(:general))
    assert_equal 1, posts(:welcome, :reload)[:taggings_count]
    tagging.destroy
    assert posts(:welcome, :reload)[:taggings_count].zero?
  end

  private
    # create dynamic Post models to allow different dependency options
    def find_post_with_dependency(post_id, association, association_name, dependency)
      class_name = "PostWith#{association.to_s.classify}#{dependency.to_s.classify}"
      Post.find(post_id).update_attribute :type, class_name
      klass = Object.const_set(class_name, Class.new(ActiveRecord::Base))
      klass.set_table_name 'posts'
      klass.send(association, association_name, :as => :taggable, :dependent => dependency)
      klass.find(post_id)
    end
end
