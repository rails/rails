require 'cases/helper'
require 'models/contact'
require 'models/sheep'
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

  def test_collection
    assert_equal 'post/track_backs', @model_name.collection
  end

  def test_partial_path
    assert_equal 'post/track_backs/track_back', @model_name.partial_path
  end
end

class NamingHelpersTest < Test::Unit::TestCase
  def setup
    @klass  = Contact
    @record = @klass.new
    @singular = 'contact'
    @plural = 'contacts'
    @uncountable = Sheep
  end

  def test_singular
    assert_equal @singular, singular(@record)
  end

  def test_singular_for_class
    assert_equal @singular, singular(@klass)
  end

  def test_plural
    assert_equal @plural, plural(@record)
  end

  def test_plural_for_class
    assert_equal @plural, plural(@klass)
  end

  def test_uncountable
    assert uncountable?(@uncountable), "Expected 'sheep' to be uncoutable"
    assert !uncountable?(@klass), "Expected 'contact' to be countable"
  end

  private
    def method_missing(method, *args)
      ActiveModel::Naming.send(method, *args)
    end
end

