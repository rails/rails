require 'abstract_unit'
require 'fixtures/tag'
require 'fixtures/tagging'
require 'fixtures/post'
require 'fixtures/comment'

class AssociationsJoinModelTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false
  fixtures :posts, :comments, :tags, :taggings

  def test_polymorphic_has_many
    assert_equal taggings(:welcome_general), posts(:welcome).taggings.first
  end

  def test_polymorphic_belongs_to
    assert_equal posts(:welcome), posts(:welcome).taggings.first.taggable
  end

  def test_polymorphic_has_many_going_through_join_model
    assert_equal tags(:general), posts(:welcome).tags.first
  end
end
