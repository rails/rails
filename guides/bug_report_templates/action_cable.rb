# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"

  gem "puma"
  gem "capybara"
  gem "selenium-webdriver"
end

require "action_controller/railtie"
require "action_cable/engine"

class TestApp < Rails::Application
  config.root = __dir__
  config.eager_load = false

  config.logger = Logger.new($stdout)
  Rails.logger  = config.logger

  config.action_cable.cable = { "adapter" => "async" }

  routes.append do
    get "/test" => "test#index"
    get "/broadcast" => "test#broadcast"
  end
end

class TestController < ActionController::Base
  include Rails.application.routes.url_helpers

  def index
    render inline: DATA.read
  end

  def broadcast
    ActionCable.server.broadcast "test_channel", { message: "hello" }
    render plain: "ok"
  end
end

class TestChannel < ActionCable::Channel::Base
  def subscribed
    stream_from "test_channel"
  end
end

Rails.application.initialize!

require "minitest/autorun"

class BugTest < ActionDispatch::SystemTestCase
  options = {
    browser: ENV["SELENIUM_DRIVER_URL"] ? :remote : :chrome,
    url: ENV["SELENIUM_DRIVER_URL"] ? ENV["SELENIUM_DRIVER_URL"] : nil
  }
  driven_by :selenium, using: :headless_chrome, options: options

  test "sends logs from the server" do
    visit "/test"

    click_button "Broadcast"
    logs = find("#log")
    assert_equal '{"message":"hello"}', logs.value
  end
end

Capybara.server_host = "0.0.0.0"
Capybara.app_host = "http://#{IPSocket.getaddress(Socket.gethostname)}" if ENV["SELENIUM_DRIVER_URL"]

__END__
<html>
<head>
  <script type="importmap">
    {
      "imports": {
        "@rails/actioncable": "https://jspm.dev/@rails/actioncable"
      }
    }
  </script>

  <script type="module">
    import * as ActionCable from "@rails/actioncable"

    ActionCable.logger.enabled = true

    const consumer = ActionCable.createConsumer()

    consumer.subscriptions.create("TestChannel", {
      received(data) {
        document.getElementById("log").value = JSON.stringify(data)
      }
    })
  </script>
</head>
<body>
  <button onclick="fetch('/broadcast')">Broadcast</button>
  <textarea id="log"></textarea>
</body>
</html>
