# frozen_string_literal: true

require "test_helper"
require "action_view/railtie"

class ActionCable::Helpers::ActionCableHelperTest < ActionCable::TestCase
  include ActionCable::Helpers::ActionCableHelper
  include ActionView::Helpers::TagHelper

  setup { ActionCable.server.config.mount_path = "/cable" }

  def with_mock_relative_url_root(value, &block)
    config = Minitest::Mock.new
    config.expect(:relative_url_root, value)
    Rails.stub(:configuration, config, &block)
  end

  test "action_cable_meta_tag mount_path without relative_url_root" do
    with_mock_relative_url_root(nil) do
      assert_equal(
        '<meta name="action-cable-url" content="/cable" />',
        action_cable_meta_tag
      )
    end
  end

  test "action_cable_meta_tag mount_path with relative_url_root" do
    with_mock_relative_url_root("/foo") do
      assert_equal(
        '<meta name="action-cable-url" content="/foo/cable" />',
        action_cable_meta_tag
      )
    end
  end
end
