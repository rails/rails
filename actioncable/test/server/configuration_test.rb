require 'test_helper'
require 'active_support/core_ext/array/grouping'

class ActionCable::Server::ConfigurationTest < ActionCable::TestCase
  setup do
    ActionCable::Server::Configuration.any_instance.stubs(:channel_paths).returns(
      %w(/app/channels/test/test_channel.rb /app/channels/test_channel.rb)
    )

    @config = ActionCable::Server::Configuration.new
  end

  test "load namespaced channels" do
    assert_equal @config.channel_class_names, %w(Test::TestChannel TestChannel)
  end
end
