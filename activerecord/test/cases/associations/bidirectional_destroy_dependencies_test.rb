# frozen_string_literal: true

require 'cases/helper'
require 'models/content'

class BidirectionalDestroyDependenciesTest < ActiveRecord::TestCase
  fixtures :content, :content_positions

  def setup
    Content.destroyed_ids.clear
    ContentPosition.destroyed_ids.clear
  end

  def test_bidirectional_dependence_when_destroying_item_with_belongs_to_association
    content_position = ContentPosition.find(1)
    content = content_position.content
    assert_not_nil content

    content_position.destroy

    assert_equal [content_position.id], ContentPosition.destroyed_ids
    assert_equal [content.id], Content.destroyed_ids
  end

  def test_bidirectional_dependence_when_destroying_item_with_has_one_association
    content = Content.find(1)
    content_position = content.content_position
    assert_not_nil content_position

    content.destroy

    assert_equal [content.id], Content.destroyed_ids
    assert_equal [content_position.id], ContentPosition.destroyed_ids
  end

  def test_bidirectional_dependence_when_destroying_item_with_has_one_association_fails_first_time
    content = ContentWhichRequiresTwoDestroyCalls.find(1)

    2.times { content.destroy }

    assert_equal content.destroyed?, true
  end
end
