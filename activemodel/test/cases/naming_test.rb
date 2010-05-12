require 'cases/helper'
require 'models/track_back'

class NamingTest < ActiveModel::TestCase
  def setup
    @model_name = ActiveModel::Name.new(Post::TrackBack)
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

  def test_set_element
    @model_name.element = 'foo'

    assert_equal 'foo', @model_name.element
    assert_equal 'Foo', @model_name.human
    assert_equal 'post/foos', @model_name.collection
    assert_equal 'post/foos/foo', @model_name.partial_path
  end

  def test_human
    assert_equal 'Track back', @model_name.human
  end

  def test_set_collection
    @model_name.collection = 'foo'

    assert_equal 'foo', @model_name.collection
    assert_equal 'foo/track_back', @model_name.partial_path
  end

  def test_collection
    assert_equal 'post/track_backs', @model_name.collection
  end

  def test_partial_path
    assert_equal 'post/track_backs/track_back', @model_name.partial_path
  end

  def test_should_preserve_custom_collection
    @model_name.collection = 'bar'
    @model_name.element = 'foo'

    assert_equal 'foo', @model_name.element
    assert_equal 'Foo', @model_name.human
    assert_equal 'bar', @model_name.collection
    assert_equal 'bar/foo', @model_name.partial_path
  end
end
