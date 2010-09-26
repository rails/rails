require "cases/helper"
require 'models/author'
require 'models/post'
require 'models/person'
require 'models/reference'
require 'models/job'
require 'models/reader'
require 'models/comment'
require 'models/tag'
require 'models/tagging'
require 'models/owner'
require 'models/pet'
require 'models/toy'
require 'models/contract'
require 'models/company'
require 'models/developer'
require 'models/subscriber'
require 'models/book'
require 'models/subscription'

class NestedHasManyThroughAssociationsTest < ActiveRecord::TestCase
  fixtures :authors, :books, :posts, :subscriptions, :subscribers, :tags, :taggings

  def test_has_many_through_a_has_many_through_association_on_source_reflection
    author = authors(:david)
    assert_equal [tags(:general), tags(:general)], author.tags
  end

  def test_has_many_through_a_has_many_through_association_on_through_reflection
    author = authors(:david)
    assert_equal [subscribers(:first), subscribers(:second), subscribers(:second)], author.subscribers
  end

  def test_distinct_has_many_through_a_has_many_through_association_on_source_reflection
    author = authors(:david)
    assert_equal [tags(:general)], author.distinct_tags
  end

  def test_distinct_has_many_through_a_has_many_through_association_on_through_reflection
    author = authors(:david)
    assert_equal [subscribers(:first), subscribers(:second)], author.distinct_subscribers
  end
end