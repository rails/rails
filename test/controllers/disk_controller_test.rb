require "test_helper"
require "database/setup"

require "active_storage/disk_controller"

class ActiveStorage::DiskControllerTest < ActionController::TestCase
  setup do
    @blob = create_blob
    @routes = Routes
    @controller = ActiveStorage::DiskController.new
  end

  test "showing blob inline" do
    get :show, params: { filename: @blob.filename, encoded_key: ActiveStorage.verifier.generate(@blob.key, expires_in: 5.minutes, purpose: :blob_key) }
    assert_equal "inline; filename=\"#{@blob.filename}\"", @response.headers["Content-Disposition"]
    assert_equal "text/plain", @response.headers["Content-Type"]
  end

  test "sending blob as attachment" do
    get :show, params: { filename: @blob.filename, encoded_key: ActiveStorage.verifier.generate(@blob.key, expires_in: 5.minutes, purpose: :blob_key), disposition: :attachment }
    assert_equal "attachment; filename=\"#{@blob.filename}\"", @response.headers["Content-Disposition"]
    assert_equal "text/plain", @response.headers["Content-Type"]
  end
end
