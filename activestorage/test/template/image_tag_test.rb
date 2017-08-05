require "test_helper"
require "database/setup"

class User < ActiveRecord::Base
  has_one_attached :avatar
end

class ActiveStorage::ImageTagTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  setup do
    @user = User.create!(name: "DHH")
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

  test "attachment on a model" do
    @user.avatar.attach @blob
    assert_dom_equal %(<img alt="Racecar" src="#{polymorphic_url @user.avatar}" />), image_tag(@user.avatar)
  end

  test "error when nothing's attached" do
    assert_not @user.avatar.attached?
    assert_raises { image_tag(@user.avatar) }
  end
end
