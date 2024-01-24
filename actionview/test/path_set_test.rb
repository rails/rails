# frozen_string_literal: true

require "abstract_unit"

class PathSetTest < ActiveSupport::TestCase
  setup do
    @path_set = ActionView::PathSet.new
  end

  test "find_all with invalid format raises" do
    details = { formats: [:txt] }
    ex = assert_raises(ArgumentError) do
      @path_set.find_all(nil, nil, nil, details, nil, nil)
    end
    assert_equal "Invalid formats: :txt", ex.message
  end

  test "find_all with invalid formats raises" do
    details = { formats: [:txt, :text, :htm, :html] }
    ex = assert_raises(ArgumentError) do
      @path_set.find_all(nil, nil, nil, details, nil, nil)
    end
    assert_equal "Invalid formats: :txt, :htm", ex.message
  end

  test "exists? with invalid format raises" do
    details = { formats: [:txt] }
    ex = assert_raises(ArgumentError) do
      @path_set.exists?(nil, nil, nil, details, nil, nil)
    end
    assert_equal "Invalid formats: :txt", ex.message
  end

  test "find with invalid format raises" do
    details = { formats: [:txt] }
    ex = assert_raises(ArgumentError) do
      @path_set.find(nil, nil, nil, details, nil, nil)
    end
    assert_equal "Invalid formats: :txt", ex.message
  end
end
