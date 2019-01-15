# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::ImageTagTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "model delivery methods" do
    user = User.new(name: "Tom", proxied_image: @blob)
    user.direct_images.attach(@blob)

    assert_match 'blobs_proxy', image_tag(user.proxied_image)
    assert_match 'representations_proxy', image_tag(user.proxied_image.variant(resize: "100x100"))
    assert_equal polymorphic_url(user.direct_images.first)[0..200], @blob.service_url[0..200]
    assert_equal polymorphic_url(user.direct_images.first.variant(resize: "100x100"))[0..200], @blob.variant(resize: "100x100").service_url[0..200] 
  end
end
