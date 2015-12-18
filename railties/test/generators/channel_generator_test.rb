require 'generators/generators_test_helper'
require 'rails/generators/channel/channel_generator'

class ChannelGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_channel_skeleton_is_created
    Rails::Generators.options[:rails][:assets] = true
    run_generator ["appearance"]

    assert_file "app/channels/appearance_channel.rb" do |channel|
      assert_match(/class AppearanceChannel < ApplicationCable::Channel/, channel)
    end

    assert_file "app/assets/javascripts/channels/appearance.coffee" do |channel|
      assert_match(/App.cable.subscriptions.create "AppearanceChannel"/, channel)
    end
  end

  def test_api_only_skips_js_creation
    Rails::Generators.options[:rails][:assets] = false
    run_generator ["appearance"]

    assert_file "app/channels/appearance_channel.rb" do |channel|
      assert_match(/class AppearanceChannel < ApplicationCable::Channel/, channel)
    end

    assert_no_file "app/assets/javascripts/channels/appearance.coffee"
  end
end
