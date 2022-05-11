# frozen_string_literal: true

require "cases/helper"
require "models/comment"
require "models/post"

class PatternMatchingTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  def test_matching_attributes
    case posts(:welcome)
    in { title: "Welcome to the weblog", body: }
      assert_equal("Such a lovely day", body)
    else
      flunk("Unable to pattern match")
    end
  end

  def test_matching_relations
    case posts(:welcome)
    in { title: "Welcome to the weblog", comments: }
      assert_equal(2, comments.size)
    else
      flunk("Unable to pattern match")
    end
  end

  def test_matching_relations_attributes
    case posts(:thinking)
    in { title: "So I was thinking", body:, comments: [{ body: "Don't think too hard" }] }
      assert_equal("Like I hopefully always am", body)
    else
      flunk("Unable to pattern match")
    end
  end

  def test_matching_relations_classes
    case posts(:thinking)
    in { title: "So I was thinking", comments: [Comment[body:]] }
      assert_equal("Don't think too hard", body)
    else
      flunk("Unable to pattern match")
    end
  end
end
