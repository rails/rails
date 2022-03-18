# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/channel/channel_generator"

class ChannelGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests Rails::Generators::ChannelGenerator

  setup do
    use_with_javascript
    use_under_importmap
  end

  test "shared channel files are created" do
    run_generator ["books"]

    assert_file "app/channels/application_cable/channel.rb" do |cable|
      assert_match(/module ApplicationCable\n  class Channel < ActionCable::Channel::Base\n/, cable)
    end

    assert_file "app/channels/application_cable/connection.rb" do |cable|
      assert_match(/module ApplicationCable\n  class Connection < ActionCable::Connection::Base\n/, cable)
    end
  end

  test "specific channel files are created under importmap" do
    run_generator ["chat"]

    assert_file "app/channels/chat_channel.rb" do |channel|
      assert_match(/class ChatChannel < ApplicationCable::Channel/, channel)
    end

    assert_file "app/javascript/channels/chat_channel.js" do |channel|
      assert_match(/import consumer from "channels\/consumer"\s+consumer\.subscriptions\.create\("ChatChannel/, channel)
    end
  end

  test "specific channel files are created under node" do
    use_under_node
    generator(["chat"]).stub(:install_javascript_dependencies, true) do
      run_generator_instance

      assert_file "app/javascript/channels/chat_channel.js" do |channel|
        assert_match(/import consumer from ".\/consumer"\s+consumer\.subscriptions\.create\("ChatChannel/, channel)
      end
    end
  end

  test "channel with multiple actions is created" do
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

  test "shared channel javascript files are created" do
    run_generator ["books"]

    assert_file "app/javascript/channels/index.js"
    assert_file "app/javascript/channels/consumer.js"
  end

  test "import channels in javascript entrypoint" do
    run_generator ["books"]

    assert_file "app/javascript/application.js" do |entrypoint|
      assert_match %r|import "channels"|, entrypoint
    end
  end

  test "import channels in javascript entrypoint under node" do
    use_under_node
    generator(["chat"]).stub(:install_javascript_dependencies, true) do
      run_generator_instance

      assert_file "app/javascript/application.js" do |entrypoint|
        assert_match %r|import "./channels"|, entrypoint
      end
    end
  end

  test "pin javascript dependencies" do
    run_generator ["chat"]

    assert_file "config/importmap.rb" do |content|
      assert_match %r|pin "@rails/actioncable"|, content
      assert_match %r|pin_all_from "app/javascript/channels"|, content
    end
  end

  test "first setup only happens once" do
    run_generator ["chat"]
    assert_file "app/javascript/channels/consumer.js"

    FileUtils.rm("#{destination_root}/app/javascript/channels/consumer.js")
    run_generator ["another"]
    assert_no_file "app/javascript/channels/consumer.js"
  end

  test "javascripts not generated when assets are skipped" do
    run_generator ["chat", "--skip-assets"]

    assert_file "app/channels/chat_channel.rb" do |channel|
      assert_match(/class ChatChannel < ApplicationCable::Channel/, channel)
    end

    assert_no_file "app/javascript/channels/chat_channel.js"
  end

  test "invokes default test framework" do
    run_generator %w(chat -t=test_unit)

    assert_file "test/channels/chat_channel_test.rb" do |test|
      assert_match(/class ChatChannelTest < ActionCable::Channel::TestCase/, test)
      assert_match(/# test "subscribes" do/, test)
      assert_match(/#   assert subscription.confirmed\?/, test)
    end
  end

  test "revoking" do
    run_generator ["chat"]
    run_generator ["chat"], behavior: :revoke

    assert_no_file "app/channels/chat_channel.rb"
    assert_no_file "app/javascript/channels/chat_channel.js"
    assert_no_file "test/channels/chat_channel_test.rb"

    assert_file "app/channels/application_cable/channel.rb"
    assert_file "app/channels/application_cable/connection.rb"
    assert_file "app/javascript/channels/consumer.js"
  end

  test "channel suffix is not duplicated" do
    run_generator ["chat_channel"]

    assert_no_file "app/channels/chat_channel_channel.rb"
    assert_file "app/channels/chat_channel.rb"

    assert_no_file "app/javascript/channels/chat_channel_channel.js"
    assert_file "app/javascript/channels/chat_channel.js"

    assert_no_file "test/channels/chat_channel_channel_test.rb"
    assert_file "test/channels/chat_channel_test.rb"
  end

  private
    def use_with_javascript
      FileUtils.mkdir_p("#{destination_root}/app/javascript")
      FileUtils.touch("#{destination_root}/app/javascript/application.js")
    end

    def use_under_importmap
      FileUtils.mkdir_p("#{destination_root}/config")
      FileUtils.touch("#{destination_root}/config/importmap.rb")
      FileUtils.rm_rf("#{destination_root}/package.json")
    end

    def use_under_node
      FileUtils.touch("#{destination_root}/package.json")
      FileUtils.rm_rf("#{destination_root}/config/importmap.rb")
    end
end
