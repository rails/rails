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
        get "/one", to: "my#one"
        get "/two", to: "my#two"
      end
    RUBY

    assert_includes run_unused_routes_command(allow_failure: true), <<~OUTPUT
      Found 2 unused routes:

      Prefix Verb URI Pattern    Controller#Action
         one GET  /one(.:format) my#one
         two GET  /two(.:format) my#two
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

  test "engine with unused routes" do
    setup_blog_engines_app!

    diagnostic = <<~OUTPUT
      Routes for Blog::Engine:
      Found 1 unused route:

      Prefix Verb URI Pattern      Controller#Action
             POST /posts(.:format) blog/posts#create

      Routes for Auth::Engine:
      Found 1 unused route:

      Prefix Verb URI Pattern      Controller#Action
       login GET  /login(.:format) sessions#new
    OUTPUT

    assert_equal <<~OUTPUT, run_unused_routes_command(allow_failure: true)
      Routes for application:
      No unused routes found.

      #{diagnostic.rstrip}
    OUTPUT

    assert_equal diagnostic, run_unused_routes_command(["--brief"], allow_failure: true)
  end

  test "engine with unused routes filtered" do
    setup_blog_engines_app!

    assert_equal <<~OUTPUT, run_unused_routes_command(["-c", "posts"], allow_failure: true)
      Routes for application:
      No unused routes found for this controller.

      Routes for Blog::Engine:
      Found 1 unused route:

      Prefix Verb URI Pattern      Controller#Action
             POST /posts(.:format) blog/posts#create

      Routes for Auth::Engine:
      No unused routes found for this controller.
    OUTPUT

    assert_equal <<~OUTPUT, run_unused_routes_command(["-g", "new"], allow_failure: true)
      Routes for application:
      No unused routes found for this grep pattern.

      Routes for Blog::Engine:
      No unused routes found for this grep pattern.

      Routes for Auth::Engine:
      Found 1 unused route:

      Prefix Verb URI Pattern      Controller#Action
       login GET  /login(.:format) sessions#new
    OUTPUT

    assert_equal <<~OUTPUT, run_unused_routes_command(["--brief", "-g", "new"], allow_failure: true)
      Routes for Auth::Engine:
      Found 1 unused route:

      Prefix Verb URI Pattern      Controller#Action
       login GET  /login(.:format) sessions#new
    OUTPUT

    assert_equal <<~OUTPUT, run_unused_routes_command(["--brief", "-c", "nothing"])
      No unused routes found for this controller.
    OUTPUT
  end

  test "engine with no unused routes" do
    setup_blog_engines_app!

    # remove the blog route and implement the auth route.
    engine "blog" do |e|
      e.write "config/routes.rb", <<-RUBY
        Blog::Engine.routes.draw do
          get "/posts", to: "posts#index"
          # post "/posts", to: "posts#create"
          mount Auth::Engine => "/auth"
        end
      RUBY
    end

    engine "auth" do |e|
      e.write "app/controllers/sessions_controller.rb", <<-RUBY
        class SessionsController < ActionController::Base
          def new; end
        end
      RUBY
    end

    assert_equal <<~OUTPUT, run_unused_routes_command
      Routes for application:
      No unused routes found.

      Routes for Blog::Engine:
      No unused routes found.

      Routes for Auth::Engine:
      No unused routes found.
    OUTPUT

    assert_equal <<~OUTPUT, run_unused_routes_command(["--brief"])
      No unused routes found.
    OUTPUT
  end

  private
    def run_unused_routes_command(args = [], allow_failure: false)
      rails "unused_routes", args, allow_failure: allow_failure
    end

    def setup_blog_engines_app!
      engine "blog" do |e|
        e.write "lib/blog.rb", <<-RUBY
          module Blog
            class Engine < Rails::Engine
              isolate_namespace Blog
            end
          end
        RUBY

        e.write "app/controllers/blog/posts_controller.rb", <<-RUBY
          class Blog::PostsController < ActionController::Base
            def index; end
          end
        RUBY

        e.write "config/routes.rb", <<-RUBY
          Blog::Engine.routes.draw do
            get "/posts", to: "posts#index"
            post "/posts", to: "posts#create" # no action
            mount Auth::Engine => "/auth"
          end
        RUBY
      end

      engine "auth" do |e|
        e.write "lib/auth.rb", <<-RUBY
          module Auth
            class Engine < Rails::Engine; end
          end
        RUBY

        e.write "config/routes.rb", <<-RUBY
          Auth::Engine.routes.draw do
            get "/login", to: "sessions#new" # no controller
          end
        RUBY
      end

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          mount Blog::Engine => "/blog"
        end
      RUBY
    end
end
