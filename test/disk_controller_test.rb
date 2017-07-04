require "test_helper"
require "database/setup"

require "action_controller"
require "action_controller/test_case"

require "active_file/disk_controller"
require "active_file/verified_key_with_expiration"

class ActiveFile::DiskControllerTest < ActionController::TestCase
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |routes|
    routes.draw do
      get "/rails/blobs/:encoded_key" => "active_file/disk#show", as: :rails_disk_blob
    end
  end

  setup do
    @blob = create_blob
    @routes = Routes
    @controller = ActiveFile::DiskController.new
  end

  test "showing blob inline" do
    get :show, params: { encoded_key: ActiveFile::VerifiedKeyWithExpiration.encode(@blob.key, expires_in: 5.minutes) }
    assert_equal "inline; filename=\"#{@blob.filename}\"", @response.headers["Content-Disposition"]
    assert_equal "text/plain", @response.headers["Content-Type"]
  end

  test "sending blob as attachment" do
    get :show, params: { encoded_key: ActiveFile::VerifiedKeyWithExpiration.encode(@blob.key, expires_in: 5.minutes), disposition: :attachment }
    assert_equal "attachment; filename=\"#{@blob.filename}\"", @response.headers["Content-Disposition"]
    assert_equal "text/plain", @response.headers["Content-Type"]
  end
end
