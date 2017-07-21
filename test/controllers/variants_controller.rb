require "test_helper"
require "database/setup"

require "active_storage/variants_controller"
require "active_storage/verified_key_with_expiration"

class ActiveStorage::VariantsControllerTest < ActionController::TestCase
  setup do
    @blob = ActiveStorage::Blob.create_after_upload! \
      filename: "racecar.jpg", content_type: "image/jpeg",
      io: File.open(File.expand_path("../../fixtures/files/racecar.jpg", __FILE__))

    @routes = Routes
    @controller = ActiveStorage::VariantsController.new
  end

  test "showing variant inline" do
    get :show, params: {
      filename: @blob.filename,
      encoded_blob_key: ActiveStorage::VerifiedKeyWithExpiration.encode(@blob.key, expires_in: 5.minutes),
      variation_key: ActiveStorage::Variation.encode(resize: "100x100") }

    assert_redirected_to /racecar.jpg\?disposition=inline/
  end
end
