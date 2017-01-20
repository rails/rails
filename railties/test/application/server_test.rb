require "isolation/abstract_unit"
require "rails/command"
require "rails/commands/server/server_command"

module ApplicationTests
  class ServerTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "deprecate support of older `config.ru`" do
      remove_file "config.ru"
      app_file "config.ru", <<-RUBY
        require_relative 'config/environment'
        run AppTemplate::Application
      RUBY

      server = Rails::Server.new(config: "#{app_path}/config.ru")
      server.app

      log = File.read(Rails.application.config.paths["log"].first)
      assert_match(/DEPRECATION WARNING: Use `Rails::Application` subclass to start the server is deprecated/, log)
    end
  end
end
