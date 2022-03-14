# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::VideoTagTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  setup do
    @blob = create_file_blob filename: "video.mp4"
  end

  test "blob" do
    assert_dom_equal %(<video src="#{polymorphic_url @blob}" />), video_tag(@blob)
  end

  test "attachment" do
    attachment = ActiveStorage::Attachment.new(blob: @blob)
    assert_dom_equal %(<video src="#{polymorphic_url attachment}" />), video_tag(attachment)
  end

  test "error when attachment's empty" do
    @user = User.create!(name: "DHH")

    assert_not_predicate @user.intro_video, :attached?
    assert_raises(ArgumentError) { video_tag(@user.intro_video) }
  end

  test "error when object can't be resolved into URL" do
    unresolvable_object = ActionView::Helpers::AssetTagHelper
    assert_raises(ArgumentError) { video_tag(unresolvable_object) }
  end
end
