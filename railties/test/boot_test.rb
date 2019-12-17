# frozen_string_literal: true

require "isolation/abstract_unit"

class BootTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :build_app
  teardown :teardown_app

  test "no rails components are loaded when running initializers" do
    tweak_config

    assert_nothing_raised do
      app("development")
    end
  end

  test "notification is sent when a Rails component is triggered when initializers are ran" do
    tweak_config
    app_file("config/initializers/000_my_initializer.rb", <<~RUBY)
      ActiveRecord::Base
      ActionController::Base
    RUBY

    error = assert_raises(RuntimeError) do
      app("development")
    end
    assert_match("Here are the components that got loaded too early:", error.message)
    assert_match("active_record, action_controller", error.message)
  end

  private
    def tweak_config
      remove_from_file("#{app_path}/config/environment.rb", "Rails.application.initialize!")

      app_file("config/environment.rb", <<~RUBY, "a+")
        block = ->(_, _, _, _, payload) do
          raise(RuntimeError, <<~EOM)
            One or many components were referenced too early during boot.
            This is most likely due because an initializer make use of a component before this one had time to be loaded.
            Here are the components that got loaded too early:

            \#{payload[:components].join(', ')}
          EOM
        end

        ActiveSupport::Notifications.subscribed(block, 'components_loaded.rails') do
          Rails.application.initialize!
        end
      RUBY
    end
end
