require "test_helper"
require "database/setup"

require "active_storage/variants_controller"
require "active_storage/verified_key_with_expiration"

class ActiveStorage::VariantsControllerTest < ActionController::TestCase
  setup do
    @routes = Routes
    @controller = ActiveStorage::VariantsController.new

    @blob = create_image_blob filename: "racecar.jpg"
  end

  test "showing variant inline" do
    get :show, params: {
      filename: @blob.filename,
      encoded_blob_key: ActiveStorage::VerifiedKeyWithExpiration.encode(@blob.key, expires_in: 5.minutes),
      variation_key: ActiveStorage::Variation.encode(resize: "100x100") }

    assert_redirected_to /racecar.jpg\?disposition=inline/
  end
end
