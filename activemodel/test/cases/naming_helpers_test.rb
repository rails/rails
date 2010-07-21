require 'cases/helper'

class Comment
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  def to_key; id ? [id] : nil end
  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new comment' : "comment ##{@id}"
  end
end

class Sheep
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  def to_key; id ? [id] : nil end
  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new sheep' : "sheep ##{@id}"
  end
end

class NamingHelpersTest < Test::Unit::TestCase
  def setup
    @klass  = Comment
    @record = @klass.new
    @singular = 'comment'
    @plural = 'comments'
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
    assert_equal true, uncountable?(@uncountable)
    assert_equal false, uncountable?(@klass)
  end

  private
    def method_missing(method, *args)
      ActiveModel::Naming.send(method, *args)
    end
end
