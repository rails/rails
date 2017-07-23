require "test_helper"
require "database/setup"

require "active_storage/variants_controller"

class ActiveStorage::VariantsControllerTest < ActionController::TestCase
  setup do
    @routes = Routes
    @controller = ActiveStorage::VariantsController.new

    @blob = create_image_blob filename: "racecar.jpg"
  end

  test "showing variant inline" do
    get :show, params: {
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize: "100x100") }

    assert_redirected_to /racecar.jpg\?disposition=inline/
    assert_same_image "racecar-100x100.jpg", @blob.variant(resize: "100x100")
  end
end
