# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/channel/channel_generator"

class ChannelGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests Rails::Generators::ChannelGenerator

  setup do
    FileUtils.mkdir_p("#{destination_root}/app/javascript")
    FileUtils.touch("#{destination_root}/app/javascript/application.js")

    FileUtils.mkdir_p("#{destination_root}/config")
    FileUtils.touch("#{destination_root}/config/importmap.rb")
  end

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

    assert_file "app/javascript/channels/chat_channel.js" do |channel|
      assert_match(/import consumer from "channels\/consumer"\s+consumer\.subscriptions\.create\("ChatChannel/, channel)
    end
  end

  def test_channel_with_multiple_actions_is_created
    run_generator ["chat", "speak", "mute"]

    assert_file "app/channels/chat_channel.rb" do |channel|
      assert_match(/class ChatChannel < ApplicationCable::Channel/, channel)
      assert_match(/def speak/, channel)
      assert_match(/def mute/, channel)
    end

    assert_file "app/javascript/channels/chat_channel.js" do |channel|
      assert_match(/import consumer from "channels\/consumer"\s+consumer\.subscriptions\.create\("ChatChannel/, channel)
      assert_match(/,\n\n  speak/, channel)
      assert_match(/,\n\n  mute: function\(\) \{\n    return this\.perform\('mute'\);\n  \}\n\}\);/, channel)
    end
  end

  def test_javascript_dependencies_are_pinned
    run_generator ["chat"]

    assert_file "config/importmap.rb" do |content|
      assert_match %r|pin "@rails/actioncable"|, content
      assert_match %r|pin_all_from "app/javascript/channels"|, content
    end
  end

  def test_channels_index_is_included_in_application_entrypoint
    run_generator ["chat"]

    assert_file "app/javascript/application.js" do |content|
      assert_match %r|import "channels"|, content
    end
  end

  def test_channel_first_setup_only_happens_once
    run_generator ["chat"]
    assert_file "app/javascript/channels/consumer.js"

    FileUtils.rm("#{destination_root}/app/javascript/channels/consumer.js")
    run_generator ["another"]
    assert_no_file "app/javascript/channels/consumer.js"
  end

  def test_channel_is_created_with_node_path_loading
    run_generator ["chat"]

    # Prevent yarn add from running by doing this as a second run
    FileUtils.touch("#{destination_root}/package.json")
    run_generator ["another"]

    assert_file "app/javascript/channels/another_channel.js" do |channel|
      assert_match(/import consumer from ".\/consumer"\s+consumer\.subscriptions\.create\("AnotherChannel/, channel)
    end
  end

  def test_channel_asset_is_not_created_when_skip_assets_is_passed
    run_generator ["chat", "--skip-assets"]

    assert_file "app/channels/chat_channel.rb" do |channel|
      assert_match(/class ChatChannel < ApplicationCable::Channel/, channel)
    end

    assert_no_file "app/javascript/channels/chat_channel.js"
  end

  def test_invokes_default_test_framework
    run_generator %w(chat -t=test_unit)

    assert_file "test/channels/chat_channel_test.rb" do |test|
      assert_match(/class ChatChannelTest < ActionCable::Channel::TestCase/, test)
      assert_match(/# test "subscribes" do/, test)
      assert_match(/#   assert subscription.confirmed\?/, test)
    end
  end

  def test_channel_on_revoke
    run_generator ["chat"]
    run_generator ["chat"], behavior: :revoke

    assert_no_file "app/channels/chat_channel.rb"
    assert_no_file "app/javascript/channels/chat_channel.js"
    assert_no_file "test/channels/chat_channel_test.rb"

    assert_file "app/channels/application_cable/channel.rb"
    assert_file "app/channels/application_cable/connection.rb"
    assert_file "app/javascript/channels/consumer.js"
  end

  def test_channel_suffix_is_not_duplicated
    run_generator ["chat_channel"]

    assert_no_file "app/channels/chat_channel_channel.rb"
    assert_file "app/channels/chat_channel.rb"

    assert_no_file "app/javascript/channels/chat_channel_channel.js"
    assert_file "app/javascript/channels/chat_channel.js"

    assert_no_file "test/channels/chat_channel_channel_test.rb"
    assert_file "test/channels/chat_channel_test.rb"
  end
end
