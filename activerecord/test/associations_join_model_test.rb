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

  def test_polymorphic_belongs_to
    assert_equal posts(:welcome), posts(:welcome).taggings.first.taggable
  end

  def test_polymorphic_has_many_going_through_join_model
    assert_equal tags(:general), posts(:welcome).tags.first
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
  
  def test_has_many_with_piggyback
    assert_equal "2", categories(:sti_test).authors.first.post_id.to_s
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
    assert_equal categories(:general), authors(:david).categories.find_by_name('General')
#    assert_equal nil, authors(:david).categories.find_by_name('Technology')
  end
    
end
