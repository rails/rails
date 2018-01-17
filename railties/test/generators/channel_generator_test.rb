# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/channel/channel_generator"

class ChannelGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests Rails::Generators::ChannelGenerator

  def test_application_cable_skeleton_is_created
    run_generator ["books"]

    assert_file "app/channels/application_cable/channel.rb" do |cable|
      assert_match(/module ApplicationCable\n  class Channel < ActionCable::Channel::Base\n/, cable)
    end

    assert_file "app/channels/application_cable/connection.rb" do |cable|
      assert_match(/module ApplicationCable\n  class Connection < ActionCable::Connection::Base\n/, cable)
    end
  end

  def test_channel_is_created
    run_generator ["chat"]

    assert_file "app/channels/chat_channel.rb" do |channel|
      assert_match(/class ChatChannel < ApplicationCable::Channel/, channel)
    end

    assert_file "app/assets/javascripts/channels/chat.js" do |channel|
      assert_match(/App\.chat = App\.cable\.subscriptions\.create\("ChatChannel/, channel)
    end
  end

  def test_channel_with_multiple_actions_is_created
    run_generator ["chat", "speak", "mute"]

    assert_file "app/channels/chat_channel.rb" do |channel|
      assert_match(/class ChatChannel < ApplicationCable::Channel/, channel)
      assert_match(/def speak/, channel)
      assert_match(/def mute/, channel)
    end

    assert_file "app/assets/javascripts/channels/chat.js" do |channel|
      assert_match(/App\.chat = App\.cable\.subscriptions\.create\("ChatChannel/, channel)
      assert_match(/,\n\n  speak/, channel)
      assert_match(/,\n\n  mute: function\(\) \{\n    return this\.perform\('mute'\);\n  \}\n\}\);/, channel)
    end
  end

  def test_channel_asset_is_not_created_when_skip_assets_is_passed
    run_generator ["chat", "--skip-assets"]

    assert_file "app/channels/chat_channel.rb" do |channel|
      assert_match(/class ChatChannel < ApplicationCable::Channel/, channel)
    end

    assert_no_file "app/assets/javascripts/channels/chat.js"
  end

  def test_cable_js_is_created_if_not_present_already
    run_generator ["chat"]
    FileUtils.rm("#{destination_root}/app/assets/javascripts/cable.js")
    run_generator ["camp"]

    assert_file "app/assets/javascripts/cable.js"
  end

  def test_channel_on_revoke
    run_generator ["chat"]
    run_generator ["chat"], behavior: :revoke

    assert_no_file "app/channels/chat_channel.rb"
    assert_no_file "app/assets/javascripts/channels/chat.js"

    assert_file "app/channels/application_cable/channel.rb"
    assert_file "app/channels/application_cable/connection.rb"
    assert_file "app/assets/javascripts/cable.js"
  end
end
