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
    
end
