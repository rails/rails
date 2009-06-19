require 'cases/helper'

class NamingTest < Test::Unit::TestCase
  def setup
    @model_name = ActiveModel::Name.new('Post::TrackBack')
  end

  def test_singular
    assert_equal 'post_track_back', @model_name.singular
  end

  def test_plural
    assert_equal 'post_track_backs', @model_name.plural
  end

  def test_element
    assert_equal 'track_back', @model_name.element
  end

  def test_collection
    assert_equal 'post/track_backs', @model_name.collection
  end

  def test_partial_path
    assert_equal 'post/track_backs/track_back', @model_name.partial_path
  end
end
