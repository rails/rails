# frozen_string_literal: true

require "isolation/abstract_unit"

class BootTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :build_app
  teardown :teardown_app

  test "no rails components are loaded at boot time in development" do
    remove_from_file("#{app_path}/config/environment.rb", "Rails.application.initialize!")

    app_file("config/environment.rb", <<~RUBY, "a+")
      block = ->(_, _, _, _, payload) do
        allowed_hooks = [:before_initialize, :after_initialize, :action_cable, :action_cable_channel]
        next if allowed_hooks.include?(payload[:name])

        raise(<<~EOM)
          The \#{payload[:base]} component was referenced too early during boot.
          This is most likely due because an initializer make use of a component before this one had time to be loaded.
        EOM
      end

      ActiveSupport::Notifications.subscribed(block, 'run_load_hooks.active_support') do
        Rails.application.initialize!
      end
    RUBY

    assert_nothing_raised do
      app("development")
    end
  end
end
