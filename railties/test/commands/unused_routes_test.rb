# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"
require "io/console/size"

class Rails::Command::UnusedRoutesTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "no results" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
      end
    RUBY

    assert_includes run_unused_routes_command, "No unused routes found."
  end

  test "no controller" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get "/", to: "my#index", as: :my_route
      end
    RUBY

    assert_includes run_unused_routes_command(allow_failure: true), <<~OUTPUT
      Found 1 unused route:

        Prefix Verb URI Pattern Controller#Action
      my_route GET  /           my#index
    OUTPUT
  end

  test "no action" do
    app_file "app/controllers/my_controller.rb", <<-RUBY
      class MyController < ActionController::Base
      end
    RUBY

    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get "/", to: "my#index", as: :my_route
      end
    RUBY

    assert_includes run_unused_routes_command(allow_failure: true), <<~OUTPUT
      Found 1 unused route:

        Prefix Verb URI Pattern Controller#Action
      my_route GET  /           my#index
    OUTPUT
  end

  test "implicit render" do
    app_file "app/controllers/my_controller.rb", <<-RUBY
      class MyController < ActionController::Base
      end
    RUBY

    app_file "app/views/my/index.html.erb", <<-HTML
      <h1>Hello world</h1>
    HTML

    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get "/", to: "my#index", as: :my_route
      end
    RUBY

    assert_includes run_unused_routes_command, "No unused routes found."
  end

  test "multiple unused routes" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get "/one", to: "action#one"
        get "/two", to: "action#two"
      end
    RUBY

    assert_includes run_unused_routes_command(allow_failure: true), <<~OUTPUT
      Found 2 unused routes:

      Prefix Verb URI Pattern    Controller#Action
         one GET  /one(.:format) action#one
         two GET  /two(.:format) action#two
    OUTPUT
  end

  test "filter by grep" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get "/one", to: "posts#one"
        get "/two", to: "users#two"
      end
    RUBY

    assert_includes run_unused_routes_command(["-g", "one"], allow_failure: true), <<~OUTPUT
      Found 1 unused route:

      Prefix Verb URI Pattern    Controller#Action
         one GET  /one(.:format) posts#one
    OUTPUT
  end

  test "filter by grep no results" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
      end
    RUBY

    assert_includes run_unused_routes_command(["-g", "one"]), <<~OUTPUT
      No unused routes found for this grep pattern.
    OUTPUT
  end

  test "filter by controller" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get "/one", to: "posts#one"
        get "/two", to: "users#two"
      end
    RUBY

    assert_includes run_unused_routes_command(["-c", "posts"], allow_failure: true), <<~OUTPUT
      Found 1 unused route:

      Prefix Verb URI Pattern    Controller#Action
         one GET  /one(.:format) posts#one
    OUTPUT
  end

  test "filter by controller no results" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
      end
    RUBY

    assert_includes run_unused_routes_command(["-c", "posts"]), <<~OUTPUT
      No unused routes found for this controller.
    OUTPUT
  end

  private
    def run_unused_routes_command(args = [], allow_failure: false)
      rails "unused_routes", args, allow_failure: allow_failure
    end
end
