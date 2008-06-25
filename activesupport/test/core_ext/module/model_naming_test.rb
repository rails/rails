require 'abstract_unit'

class ModelNamingTest < Test::Unit::TestCase
  def setup
    @name = ActiveSupport::ModelName.new('Post::TrackBack')
  end

  def test_singular
    assert_equal 'post_track_back', @name.singular
  end

  def test_plural
    assert_equal 'post_track_backs', @name.plural
  end

  def test_partial_path
    assert_equal 'post/track_backs/track_back', @name.partial_path
  end
end
