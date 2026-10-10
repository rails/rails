# frozen_string_literal: true

require "isolation/abstract_unit"

class ViewsPrecompileTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :build_app
  teardown :teardown_app

  test "views:precompile caches templates across processes" do
    enable_bootsnap
    app_file "app/views/pages/show.html.erb", "<%= message %>"
    app_file "app/views/pages/show.text.erb", "<%= message %>"
    app_file "app/views/pages/show.xml.builder", "xml.message message"
    app_file "app/views/pages/show.html", "hello"
    app_file "app/views/pages/show.text.custom", "custom"
    app_file "config/initializers/custom_handler.rb", <<~RUBY
      module CustomHandler
        def self.call(template, source)
          source.inspect
        end
      end
      ActionView::Template.register_template_handler(:custom, CustomHandler)
    RUBY

    output = rails("views:precompile", "RAILS_ENV=production")
    assert_match(/Precompiled \d+ templates\./, output)
    assert_not_empty Dir.glob(app_path("tmp/cache/bootsnap/compile-cache-iseq-views/**/*")).select { |path| File.file?(path) }

    app_file "script/render_views.rb", <<~RUBY
      [
        ActionView::Template::Handlers::ERB,
        ActionView::Template::Handlers::Builder,
        ActionView::Template::Handlers::Html
      ].each do |handler|
        handler.class_eval do
          def call(*)
            raise "handler should not run on a cache hit"
          end
        end
      end

      def CustomHandler.call(*)
        raise "custom handler should not run on a cache hit"
      end

      view = ActionView::Base.with_empty_template_cache.with_view_paths(Rails.root.join("app/views"))
      puts view.render(template: "pages/show", formats: [:html], locals: { message: "cached" })
      puts view.render(template: "pages/show", formats: [:text], locals: { message: "cached" })
      puts view.render(template: "pages/show", formats: [:xml], locals: { message: "cached" })
      puts view.render(template: "pages/show", formats: [:html], handlers: [:html])
      puts view.render(template: "pages/show", formats: [:text], handlers: [:custom])
    RUBY

    output = rails("runner", "-e", "production", "script/render_views.rb")
    assert_equal ["cached", "cached", "<message>cached</message>", "hello", "custom"], output.lines.map(&:strip)
  end

  test "views:precompile fails clearly without Bootsnap" do
    output = rails("views:precompile", allow_failure: true)

    assert_match "views:precompile requires Bootsnap", output
    assert_not $?.success?
  end

  test "API-only applications precompile JSON templates" do
    add_to_config "config.api_only = true"
    enable_bootsnap
    app_file "app/controllers/application_controller.rb", <<~RUBY
      class ApplicationController < ActionController::API
      end
    RUBY
    app_file "app/controllers/pages_controller.rb", <<~RUBY
      class PagesController < ApplicationController
        include ActionView::Rendering
        prepend_view_path Rails.root.join("app/views")

        def show
          render template: "pages/show", formats: [:json], locals: { message: "cached" }
        end
      end
    RUBY
    app_file "app/views/pages/show.json.erb", '{"message":"<%= message %>"}'
    app_file "config/routes.rb", <<~RUBY
      Rails.application.routes.draw do
        get "/pages", to: "pages#show"
      end
    RUBY

    output = rails("views:precompile", "RAILS_ENV=production")
    assert_match(/Precompiled [1-9]\d* templates?\./, output)

    app_file "script/render_json.rb", <<~RUBY
      ActionView::Template::Handlers::ERB.class_eval do
        def call(*)
          raise "handler should not run on a cache hit"
        end
      end

      response = Rack::MockRequest.new(Rails.application).get("/pages")
      puts response.status
      puts response.body
    RUBY

    output = rails("runner", "-e", "production", "script/render_json.rb")
    assert_equal ["200", '{"message":"cached"}'], output.lines.map(&:strip)
  end

  private
    def enable_bootsnap
      app_file "config/boot.rb", <<~RUBY
        require "bootsnap"
        Bootsnap.setup(cache_dir: #{app_path("tmp/cache").inspect})
        require "rails/all"
      RUBY
    end
end
