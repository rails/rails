# frozen_string_literal: true

require "test_helper"

class ActiveStorage::RoutingTest < ActionDispatch::IntegrationTest
  test "ensuring that routes are prepended" do
    paths = Rails.application.routes.routes.map { |r| r.path.spec.to_s }
    as_position        = paths.index("/rails/active_storage/blobs/:signed_id/*filename(.:format)")
    globbing_position  = paths.index("/*(.:format)")
    assert as_position < globbing_position
  end
end
