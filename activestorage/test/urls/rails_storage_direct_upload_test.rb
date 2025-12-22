# frozen_string_literal: true

require "test_helper"
require "database/setup"

class RailsStorageDirectUploadTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @was_skip_default_direct_uploads_routes = ActiveStorage.skip_default_direct_uploads_routes
  end

  teardown do
    ActiveStorage.skip_default_direct_uploads_routes = @was_skip_default_direct_uploads_routes
  end

  test "rails registered direct upload default path" do
    ActiveStorage.skip_default_direct_uploads_routes = false

    assert_includes rails_active_storage_direct_uploads_path(only_path: true), "/rails/active_storage/direct_uploads"
  end

  test "rails skip default direct upload default path" do
    ActiveStorage.skip_default_direct_uploads_routes = true

    assert_raise(ActionController::RoutingError) { @routes.recognize_path("/rails/active_storage/direct_uploads") }
  end
end
