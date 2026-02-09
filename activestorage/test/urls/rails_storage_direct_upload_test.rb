# frozen_string_literal: true

require "test_helper"
require "database/setup"

class RailsStorageDirectUploadTest < ActiveSupport::TestCase
  setup do
    @routes = Rails.application.routes
    @was_skip_default_direct_uploads_routes = ActiveStorage.skip_default_direct_uploads_routes
  end

  teardown do
    ActiveStorage.skip_default_direct_uploads_routes = @was_skip_default_direct_uploads_routes
  end

  test "rails registered direct upload default path" do
    ActiveStorage.skip_default_direct_uploads_routes = false

    assert_equal({ controller: "active_storage/direct_uploads", action: "create" }, @routes.recognize_path("/rails/active_storage/direct_uploads", method: :post))
  end

  test "rails skip default direct upload default path" do
    ActiveStorage.skip_default_direct_uploads_routes = true

    assert_raise(ActionController::RoutingError) { @routes.recognize_path("/rails/active_storage/direct_uploads") }
  end
end
