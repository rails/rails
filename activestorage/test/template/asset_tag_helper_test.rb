# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::ImageTagTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  setup do
    @blob = create_image_blob filename: "racecar.jpg"
  end

  test "blob" do
    assert_dom_equal %(<img alt="Racecar" src="#{polymorphic_url @blob}" />), image_tag(@blob)
  end

  test "variant" do
    variant = @blob.variant(resize: "100x100")
    assert_dom_equal %(<img alt="Racecar" src="#{polymorphic_url variant}" />), image_tag(variant)
  end

  test "attachment" do
    attachment = ActiveStorage::Attachment.new(blob: @blob)
    assert_dom_equal %(<img alt="Racecar" src="#{polymorphic_url attachment}" />), image_tag(attachment)
  end

  test "error when attachment's empty" do
    @user = User.create!(name: "DHH")
    assert_not @user.avatar.attached?

    e = assert_raises(ArgumentError) { image_tag(@user.avatar) }
    assert_equal "Can't resolve object into URL: to_model delegated to attachment, but attachment is nil", e.message
  end

  test "error when object can't be resolved into url" do
    unresolvable_object = ActionView::Helpers::AssetTagHelper

    e = assert_raises(ArgumentError) { image_tag(unresolvable_object) }
    assert_match /Can't resolve object into URL: undefined method `to_model'/, e.message
  end


  test "video_tag" do
    assert_dom_equal %(<video src="#{polymorphic_url @blob}"></video>), video_tag(@blob)
  end

  test "video_tag with multiple sources" do
    poster_blob = create_blob
    video_blob = create_blob

    assert_dom_equal %(
      <video poster="#{polymorphic_url poster_blob}">
        <source src="#{polymorphic_url @blob}" />
        <source src="#{polymorphic_url video_blob}" />
      </video>
    ).gsub(/\s{2,}/, ''), video_tag(@blob, video_blob, poster: poster_blob)
  end

  test "audio_tag" do
    assert_dom_equal %(<audio src="#{polymorphic_url @blob}"></video>), audio_tag(@blob)
  end
end
