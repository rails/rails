require 'abstract_unit'
require 'fixtures/tag'
require 'fixtures/tagging'
require 'fixtures/post'
require 'fixtures/comment'

class AssociationsInterfaceTest < Test::Unit::TestCase
  fixtures :posts, :comments, :tags, :taggings

  def test_post_having_a_single_tag_through_has_many
    assert_equal taggings(:welcome_general), posts(:welcome).taggings.first
  end

  def test_post_having_a_single_tag_through_belongs_to
    assert_equal posts(:welcome), posts(:welcome).taggings.first.taggable
  end
end
