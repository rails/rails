# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "base64"
require "rails-dom-testing"

module ApplicationTests
  class MailerPreviewsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods
    include ERB::Util
    include Rails::Dom::Testing::Assertions

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "/rails/mailers is accessible in development" do
      app("development")
      get "/rails/mailers"
      assert_equal 200, last_response.status
    end

    test "/rails/mailers is not accessible in production" do
      app("production")
      get("/rails/mailers", {}, { "HTTPS" => "on" })
      assert_equal 404, last_response.status
    end

    test "/rails/mailers is accessible with correct configuration" do
      add_to_config "config.action_mailer.show_previews = true"
      app("production")
      get "/rails/mailers", {}, { "REMOTE_ADDR" => "4.2.42.42", "HTTPS" => "on" }
      assert_equal 200, last_response.status
    end

    test "/rails/mailers is not accessible with show_previews = false" do
      add_to_config "config.action_mailer.show_previews = false"
      app("development")
      get "/rails/mailers"
      assert_equal 404, last_response.status
    end

    test "/rails/mailers is accessible with globbing route present" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '*foo', to: 'foo#index'
        end
      RUBY
      app("development")
      get "/rails/mailers"
      assert_equal 200, last_response.status
    end

    test "request without mailer previews links to documentation" do
      app("development")

      get "/rails/mailers"
      assert_select "title", text: "Action Mailer Previews"
      assert_select "h1", text: "Action Mailer Previews"
      assert_select "p", text: "You have not defined any Action Mailer Previews."
      assert_select "p", text: "Read Action Mailer Basics to learn how to define your first." do
        assert_select "a[href=?]", "https://guides.rubyonrails.org/action_mailer_basics.html#previewing-emails", text: "Action Mailer Basics"
      end
    end

    test "mailer previews are loaded from the default preview_paths" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers"
      assert_select "title", text: "Action Mailer Previews"
      assert_select "h1", text: "Action Mailer Previews"
      assert_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body
      assert_match '<li><a href="/rails/mailers/notifier/foo">foo</a></li>', last_response.body
    end

    test "mailer previews are loaded from custom preview_paths" do
      app_dir "lib/mailer_previews"
      add_to_config "config.action_mailer.preview_paths = ['#{app_path}/lib/notifier_previews', '#{app_path}/lib/confirm_previews']"

      ["notifier", "confirm"].each do |keyword|
        mailer keyword, <<-RUBY
          class #{keyword.camelize} < ActionMailer::Base
            default from: "from@example.com"

            def foo
              mail to: "to@example.org"
            end
          end
        RUBY

        text_template "#{keyword}/foo", <<-RUBY
          Hello, World!
        RUBY

        app_file "lib/#{keyword}_previews/notifier_preview.rb", <<-RUBY
          class #{keyword.camelize}Preview < ActionMailer::Preview
            def foo
              #{keyword.camelize}.foo
            end
          end
        RUBY
      end

      app("development")

      get "/rails/mailers"
      assert_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body
      assert_match '<li><a href="/rails/mailers/notifier/foo">foo</a></li>', last_response.body
      assert_match '<h3><a href="/rails/mailers/confirm">Confirm</a></h3>', last_response.body
      assert_match '<li><a href="/rails/mailers/confirm/foo">foo</a></li>', last_response.body
    end

    test "mailer previews are reloaded across requests" do
      app("development")

      get "/rails/mailers"
      assert_no_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body

      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      get "/rails/mailers"
      assert_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body

      remove_file "test/mailers/previews/notifier_preview.rb"
      sleep(1)

      get "/rails/mailers"
      assert_no_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body
    end

    test "mailer preview actions are added and removed" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers"
      assert_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body
      assert_match '<li><a href="/rails/mailers/notifier/foo">foo</a></li>', last_response.body
      assert_no_match '<li><a href="/rails/mailers/notifier/bar">bar</a></li>', last_response.body

      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end

          def bar
            mail to: "to@example.net"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      text_template "notifier/bar", <<-RUBY
        Goodbye, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end

          def bar
            Notifier.bar
          end
        end
      RUBY

      sleep(1)

      get "/rails/mailers"
      assert_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body
      assert_match '<li><a href="/rails/mailers/notifier/foo">foo</a></li>', last_response.body
      assert_match '<li><a href="/rails/mailers/notifier/bar">bar</a></li>', last_response.body

      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      remove_file "app/views/notifier/bar.text.erb"

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      sleep(1)

      get "/rails/mailers"
      assert_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body
      assert_match '<li><a href="/rails/mailers/notifier/foo">foo</a></li>', last_response.body
      assert_no_match '<li><a href="/rails/mailers/notifier/bar">bar</a></li>', last_response.body
    end

    test "mailer previews are reloaded from custom preview_paths" do
      app_dir "lib/mailer_previews"
      add_to_config "config.action_mailer.preview_paths = ['#{app_path}/lib/mailer_previews']"

      app("development")

      get "/rails/mailers"
      assert_no_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body

      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      app_file "lib/mailer_previews/notifier_preview.rb", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      get "/rails/mailers"
      assert_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body

      remove_file "lib/mailer_previews/notifier_preview.rb"
      sleep(1)

      get "/rails/mailers"
      assert_no_match '<h3><a href="/rails/mailers/notifier">Notifier</a></h3>', last_response.body
    end

    test "mailer without previews" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
        end
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
        end
      RUBY

      app("development")
      get "/rails/mailers/notifier"

      assert_predicate last_response, :ok?
      assert_select "title", text: "Action Mailer Previews for notifier"
      assert_select "h1", text: "Action Mailer Previews for notifier"
      assert_select "p", text: "You have not defined any actions for NotifierPreview."
      assert_select "p", text: "Read Action Mailer Basics to learn how to define your first." do
        assert_select "a[href=?]", "https://guides.rubyonrails.org/action_mailer_basics.html#previewing-emails", text: "Action Mailer Basics"
      end
    end

    test "mailer with previews" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          def foo
          end
        end
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")
      get "/rails/mailers/notifier"

      assert_predicate last_response, :ok?
      assert_select "title", text: "Action Mailer Previews for notifier"
      assert_select "h1", text: "Action Mailer Previews for notifier"
      assert_select "ul li a[href=?]", "/rails/mailers/notifier/foo"
    end

    test "mailer preview not found" do
      app("development")
      get "/rails/mailers/notifier"
      assert_predicate last_response, :not_found?
      assert_match "Mailer preview &#39;notifier&#39; not found", h(last_response.body)
    end

    test "mailer preview email not found" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/bar"
      assert_predicate last_response, :not_found?
      assert_match "Email &#39;bar&#39; not found in NotifierPreview", h(last_response.body)

      get "/rails/mailers/download/notifier/bar"
      assert_predicate last_response, :not_found?
      assert_match "Email &#39;bar&#39; not found in NotifierPreview", h(last_response.body)
    end

    test "mailer preview NullMail" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            # does not call +mail+
          end
        end
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_match "You are trying to preview an email that does not have any content.", last_response.body
      assert_match "notifier#foo", last_response.body
    end

    test "mailer preview email part not found" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo?part=text%2Fhtml"
      assert_predicate last_response, :not_found?
      assert_match "Email part &#39;text/html&#39; not found in NotifierPreview#foo", h(last_response.body)
    end

    test "message header uses full display names" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "Ruby on Rails <core@rubyonrails.org>"

          def foo
            mail to: "Andrew White <andyw@pixeltrix.co.uk>",
                 cc: "David Heinemeier Hansson <david@heinemeierhansson.com>"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_equal 200, last_response.status
      assert_match '<dd id="from">Ruby on Rails &lt;core@rubyonrails.org&gt;</dd>', last_response.body
      assert_match '<dd id="to">Andrew White &lt;andyw@pixeltrix.co.uk&gt;</dd>', last_response.body
      assert_match '<dd id="cc">David Heinemeier Hansson &lt;david@heinemeierhansson.com&gt;</dd>', last_response.body
      assert_no_match '<dd id="smtp_from">', last_response.body
      assert_no_match '<dd id="smtp_to">', last_response.body

      get "/rails/mailers/download/notifier/foo"
      email = Mail.read_from_string(last_response.body)
      assert_equal "attachment; filename=\"foo.eml\"; filename*=UTF-8''foo.eml", last_response.headers["Content-Disposition"]
      assert_equal 200, last_response.status
      assert_equal ["andyw@pixeltrix.co.uk"], email.to
      assert_equal ["david@heinemeierhansson.com"], email.cc
    end

    test "message header shows SMTP envelope To and From when different than message headers" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            message.smtp_envelope_from = "smtp-from@example.com"
            message.smtp_envelope_to = ["to@example.com", "bcc@example.com"]

            mail to: "to@example.com"
          end
        end
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_equal 200, last_response.status
      assert_match '<dd id="from">from@example.com</dd>', last_response.body
      assert_match '<dd id="smtp_from">smtp-from@example.com</dd>', last_response.body
      assert_match '<dd id="to">to@example.com</dd>', last_response.body
      assert_match '<dd id="smtp_to">to@example.com, bcc@example.com</dd>', last_response.body
    end

    test "part menu selects correct option" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      html_template "notifier/foo", <<-RUBY
        <p>Hello, World!</p>
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo.html"
      assert_equal 200, last_response.status
      assert_select "option[selected][value]", "View as HTML email" do |option,|
        query = Rack::Utils.parse_nested_query(option["value"])
        assert_equal "text/html", query["part"]
      end

      get "/rails/mailers/notifier/foo.txt"
      assert_equal 200, last_response.status
      assert_select "option[selected][value]", "View as plain-text email" do |option,|
        query = Rack::Utils.parse_nested_query(option["value"])
        assert_equal "text/plain", query["part"]
      end
    end

    test "locale menu selects correct option" do
      app_file "config/initializers/available_locales.rb", <<-RUBY
        Rails.application.configure do
          config.i18n.available_locales = %i[en ja]
        end
      RUBY

      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      html_template "notifier/foo", <<-RUBY
        <p>Hello, World!</p>
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo.html"
      assert_equal 200, last_response.status
      assert_match '<option selected value="locale=en">en', last_response.body
      assert_match '<option  value="locale=ja">ja', last_response.body

      get "/rails/mailers/notifier/foo.html?locale=ja"
      assert_equal 200, last_response.status
      assert_match '<option  value="locale=en">en', last_response.body
      assert_match '<option selected value="locale=ja">ja', last_response.body

      get "/rails/mailers/notifier/foo.txt"
      assert_equal 200, last_response.status
      assert_match '<option selected value="locale=en">en', last_response.body
      assert_match '<option  value="locale=ja">ja', last_response.body

      get "/rails/mailers/notifier/foo.txt?locale=ja"
      assert_equal 200, last_response.status
      assert_match '<option  value="locale=en">en', last_response.body
      assert_match '<option selected value="locale=ja">ja', last_response.body
    end

    test "preview does not leak I18n global setting changes" do
      I18n.with_locale(:en) do
        get "/rails/mailers/notifier/foo.txt?locale=ja"
        assert_equal :en, I18n.locale
      end
    end

    test "mailer previews create correct links when loaded on a subdirectory" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers", {}, { "SCRIPT_NAME" => "/my_app" }
      assert_match '<h3><a href="/my_app/rails/mailers/notifier">Notifier</a></h3>', last_response.body
      assert_match '<li><a href="/my_app/rails/mailers/notifier/foo">foo</a></li>', last_response.body
    end

    test "mailer preview receives query params" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo(name)
            @name = name
            mail to: "to@example.org"
          end
        end
      RUBY

      html_template "notifier/foo", <<-RUBY
        <p>Hello, <%= @name %>!</p>
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, <%= @name %>!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo(params[:name] || "World")
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo.txt"
      assert_equal 200, last_response.status
      assert_select "iframe[name='messageBody'][src]" do |iframe,|
        query = Rack::Utils.parse_nested_query(URI.parse(iframe["src"]).query)
        assert_equal "text/plain", query["part"]
        assert query.key?("email_id")
      end
      assert_select "option[selected][value*='plain']" do |option,|
        query = Rack::Utils.parse_nested_query(option["value"])
        assert_equal "text/plain", query["part"]
        assert query.key?("email_id")
      end
      assert_select "option[value*='html']:not([selected])" do |option,|
        query = Rack::Utils.parse_nested_query(option["value"])
        assert_equal "text/html", query["part"]
        assert query.key?("email_id")
      end

      get "/rails/mailers/notifier/foo?part=text%2Fplain"
      assert_equal 200, last_response.status
      assert_match %r[Hello, World!], last_response.body

      get "/rails/mailers/notifier/foo.html?name=Ruby"
      assert_equal 200, last_response.status
      assert_select "iframe[name='messageBody'][src]" do |iframe,|
        query = Rack::Utils.parse_nested_query(URI.parse(iframe["src"]).query)
        assert_equal "Ruby", query["name"]
        assert_equal "text/html", query["part"]
        assert query.key?("email_id")
      end

      assert_select "option[selected][value*='html']" do |option,|
        query = Rack::Utils.parse_nested_query(option["value"])
        assert_equal "text/html", query["part"]
        assert query.key?("email_id")
      end

      assert_select "option[value*='plain']:not([selected])" do |option,|
        query = Rack::Utils.parse_nested_query(option["value"])
        assert_equal "Ruby", query["name"]
        assert_equal "text/plain", query["part"]
        assert query.key?("email_id")
      end

      get "/rails/mailers/notifier/foo?name=Ruby&part=text%2Fhtml"
      assert_equal 200, last_response.status
      assert_match %r[<p>Hello, Ruby!</p>], last_response.body
    end

    test "plain text mailer preview with attachment" do
      image_file "pixel.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEWzIioca/JlAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJgggo="

      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            attachments['pixel.png'] = File.binread("#{app_path}/public/images/pixel.png")
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_equal 200, last_response.status
      assert_match %[<iframe name="messageBody"], last_response.body
      assert_match %[<dt>Attachments:</dt>], last_response.body
      assert_no_match %[Inline:], last_response.body
      assert_match %[<a download="pixel.png" href="data:application/octet-stream;charset=utf-8;base64,iVBORw0K], last_response.body

      get "/rails/mailers/notifier/foo?part=text/plain"
      assert_equal 200, last_response.status
      assert_match %r[Hello, World!], last_response.body

      get "/rails/mailers/download/notifier/foo"
      assert_equal 200, last_response.status
      email = Mail.read_from_string(last_response.body)
      assert_equal 2, email.parts.size
      assert_equal "text/plain; charset=UTF-8", email.parts[0].content_type
      assert_equal "image/png; filename=pixel.png", email.parts[1].content_type
    end

    test "multipart mailer preview with attachment" do
      image_file "pixel.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEWzIioca/JlAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJgggo="

      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            attachments['pixel.png'] = File.binread("#{app_path}/public/images/pixel.png")
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      html_template "notifier/foo", <<-RUBY
        <p>Hello, World!</p>
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_equal 200, last_response.status
      assert_match %[<iframe name="messageBody"], last_response.body
      assert_match %[<dt>Attachments:</dt>], last_response.body
      assert_no_match %[Inline:], last_response.body
      assert_match %[<a download="pixel.png" href="data:application/octet-stream;charset=utf-8;base64,iVBORw0K], last_response.body

      get "/rails/mailers/notifier/foo?part=text/plain"
      assert_equal 200, last_response.status
      assert_match %r[Hello, World!], last_response.body

      get "/rails/mailers/notifier/foo?part=text/html"
      assert_equal 200, last_response.status
      assert_match %r[<p>Hello, World!</p>], last_response.body
    end

    test "multipart mailer preview with inline attachment" do
      image_file "pixel.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEWzIioca/JlAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJgggo="

      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            attachments.inline['pixel.png'] = File.binread("#{app_path}/public/images/pixel.png")
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      html_template "notifier/foo", <<-RUBY
        <p>Hello, World!</p>
        <%= image_tag attachments['pixel.png'].url %>
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_equal 200, last_response.status
      assert_match %[<iframe name="messageBody"], last_response.body
      assert_match %[<dt>Attachments:</dt>], last_response.body
      assert_match %r[\(Inline:\s+<a download="pixel.png" href="data:application/octet-stream;charset=utf-8;base64,iVBORw0K], last_response.body

      get "/rails/mailers/notifier/foo?part=text/plain"
      assert_equal 200, last_response.status
      assert_match %r[Hello, World!], last_response.body

      get "/rails/mailers/notifier/foo?part=text/html"
      assert_equal 200, last_response.status
      assert_match %r[<p>Hello, World!</p>], last_response.body
      assert_match %r[src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEWzIioca/JlAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJgggo="], last_response.body

      get "/rails/mailers/download/notifier/foo"
      email = Mail.read_from_string(last_response.body)
      assert_equal "inline; filename=pixel.png", email.attachments.inline["pixel.png"].content_disposition
    end

    test "multipart mailer preview with attached email" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            message = ::Mail.new do
              from    'foo@example.com'
              to      'bar@example.com'
              subject 'Important Message'

              text_part do
                body 'Goodbye, World!'
              end

              html_part do
                body '<p>Goodbye, World!</p>'
              end
            end

            attachments['message.eml'] = message.to_s
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      html_template "notifier/foo", <<-RUBY
        <p>Hello, World!</p>
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_equal 200, last_response.status
      assert_match %[<iframe name="messageBody"], last_response.body
      assert_match %[<dt>Attachments:</dt>], last_response.body
      assert_no_match %[Inline:], last_response.body
      assert_match %[<a download="message.eml" href="data:application/octet-stream;charset=utf-8;base64,RGF0ZTog], last_response.body

      get "/rails/mailers/notifier/foo?part=text/plain"
      assert_equal 200, last_response.status
      assert_match %r[Hello, World!], last_response.body

      get "/rails/mailers/notifier/foo?part=text/html"
      assert_equal 200, last_response.status
      assert_match %r[<p>Hello, World!</p>], last_response.body
    end

    test "multipart mailer preview with empty parts" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
      RUBY

      html_template "notifier/foo", <<-RUBY
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo?part=text/plain"
      assert_equal 200, last_response.status

      get "/rails/mailers/notifier/foo?part=text/html"
      assert_equal 200, last_response.status
    end

    test "mailer preview title tag" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_match "<title>Mailer Preview for notifier#foo</title>", last_response.body
    end

    test "mailer preview sender tags" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"
          def foo
            mail to: "to@example.org", cc: "cc@example.com", bcc: "bcc@example.com"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_match "<dd id=\"to\">to@example.org</dd>", last_response.body
      assert_match "<dd id=\"cc\">cc@example.com</dd>", last_response.body
      assert_match "<dd id=\"bcc\">bcc@example.com</dd>", last_response.body
    end

    test "mailer preview date tag renders date from message header" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org", date: Time.utc(2023, 10, 20, 10, 20, 30)
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo"
      assert_match "<dd id=\"date\">Fri, 20 Oct 2023 10:20:30 +0000</dd>", last_response.body
    end

    test "mailer preview date tag falls back to current time when date header is not present" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, World!
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      travel_to(Time.utc(2023, 10, 20, 10, 20, 30)) do
        get "/rails/mailers/notifier/foo"
      end
      assert_match "<dd id=\"date\">Fri, 20 Oct 2023 10:20:30 +0000</dd>", last_response.body
    end

    test "mailer preview has access to rendering context" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"
          def foo
            @template = params[:template]
            mail to: "to@example.org", cc: "cc@example.com", bcc: "bcc@example.com"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        <%= @template %>
      RUBY

      text_template "notifier/bar", <<-RUBY
        bar
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            # This is meant to simulate how Action Text's renderer works. See #47072.
            template = Rails::MailersController.renderer.render_to_string("notifier/bar")
            Notifier.with(template: template).foo
          end
        end
      RUBY

      app("development")

      get "/rails/mailers/notifier/foo?part=text%2Fplain"
      assert_includes last_response.body, "bar"
    end

    test "email persistence caches email objects across requests" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            @random_value = rand(1000)
            mail to: "to@example.org", subject: "Random: \#{@random_value}"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Random value: <%= @random_value %>
      RUBY

      html_template "notifier/foo", <<-RUBY
        <p>Random value: <%= @random_value %></p>
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      # First request generates email and caches it
      get "/rails/mailers/notifier/foo"
      assert_equal 200, last_response.status

      # Extract email_id from response
      email_id = nil
      assert_select "iframe[src*='email_id']" do |iframe|
        email_id = Rack::Utils.parse_nested_query(URI.parse(iframe.first["src"]).query)["email_id"]
      end
      assert_not_nil email_id

      # Get the HTML content
      get "/rails/mailers/notifier/foo?part=text%2Fhtml&email_id=#{email_id}"
      html_content = last_response.body
      random_match = html_content.match(/Random value: (\d+)/)
      assert_not_nil random_match
      first_random = random_match[1]

      # Get the plain text content with same email_id
      get "/rails/mailers/notifier/foo?part=text%2Fplain&email_id=#{email_id}"
      text_content = last_response.body
      text_random_match = text_content.match(/Random value: (\d+)/)
      assert_not_nil text_random_match
      second_random = text_random_match[1]

      # Both should have the same random value due to caching
      assert_equal first_random, second_random
    end

    test "email persistence generates new emails without email_id and reuses with valid email_id" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            @unique_id = SecureRandom.hex(8)
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Unique ID: <%= @unique_id %>
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      # First request without email_id should generate new email
      get "/rails/mailers/notifier/foo?part=text%2Fplain"
      first_content = last_response.body
      first_unique_id = first_content.match(/Unique ID: ([a-f0-9]+)/)[1]

      # Second request without email_id should generate different email
      get "/rails/mailers/notifier/foo?part=text%2Fplain"
      second_content = last_response.body
      second_unique_id = second_content.match(/Unique ID: ([a-f0-9]+)/)[1]

      # Should be different since no caching without email_id
      assert_not_equal first_unique_id, second_unique_id

      # Get email_id for caching test
      get "/rails/mailers/notifier/foo"
      email_id = nil
      assert_select "iframe[src*='email_id']" do |iframe|
        email_id = Rack::Utils.parse_nested_query(URI.parse(iframe.first["src"]).query)["email_id"]
      end

      # Requests with same email_id should reuse cached email
      get "/rails/mailers/notifier/foo?part=text%2Fplain&email_id=#{email_id}"
      cached_content = last_response.body
      cached_unique_id = cached_content.match(/Unique ID: ([a-f0-9]+)/)[1]

      get "/rails/mailers/notifier/foo?part=text%2Fplain&email_id=#{email_id}"
      reused_content = last_response.body
      reused_unique_id = reused_content.match(/Unique ID: ([a-f0-9]+)/)[1]

      # Should be identical due to caching
      assert_equal cached_unique_id, reused_unique_id
    end

    test "email persistence maintains consistency across iframe requests" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo
            @counter = rand(10000)
            mail to: "to@example.org", subject: "Counter: \#{@counter}"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Counter: <%= @counter %>
      RUBY

      html_template "notifier/foo", <<-RUBY
        <p>Counter: <%= @counter %></p>
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo
          end
        end
      RUBY

      app("development")

      # Get main preview page with HTML format to ensure multipart
      get "/rails/mailers/notifier/foo.html"
      assert_equal 200, last_response.status

      # Store main page content for subject verification
      main_page_content = last_response.body

      # Verify iframe src contains email_id
      iframe_src = nil
      assert_select "iframe[name='messageBody']" do |iframe|
        iframe_src = iframe.first["src"]
      end
      assert_not_nil iframe_src
      assert_match(/email_id=/, iframe_src)

      # Extract email_id from iframe src
      query_params = Rack::Utils.parse_nested_query(URI.parse(iframe_src).query)
      email_id = query_params["email_id"]
      assert_not_nil email_id

      # Request HTML content with email_id
      get "/rails/mailers/notifier/foo?part=text%2Fhtml&email_id=#{email_id}"
      html_content = last_response.body
      html_counter_match = html_content.match(/Counter: (\d+)/)
      assert_not_nil html_counter_match
      html_counter = html_counter_match[1]

      # Request plain text content with same email_id
      get "/rails/mailers/notifier/foo?part=text%2Fplain&email_id=#{email_id}"
      text_content = last_response.body
      text_counter_match = text_content.match(/Counter: (\d+)/)
      assert_not_nil text_counter_match
      text_counter = text_counter_match[1]

      # Both should have same counter value due to persistence
      assert_equal html_counter, text_counter

      # Test subject consistency - subject is shown in main preview page header
      subject_match = main_page_content.match(/<strong id="subject">Counter: (\d+)<\/strong>/)
      assert_not_nil subject_match
      subject_counter = subject_match[1]

      # Subject should match body counter
      assert_equal html_counter, subject_counter
    end



    test "email persistence works with parameterized previews" do
      mailer "notifier", <<-RUBY
        class Notifier < ActionMailer::Base
          default from: "from@example.com"

          def foo(name)
            @name = name
            @random = rand(1000)
            mail to: "to@example.org"
          end
        end
      RUBY

      text_template "notifier/foo", <<-RUBY
        Hello, <%= @name %>! Random: <%= @random %>
      RUBY

      html_template "notifier/foo", <<-RUBY
        <p>Hello, <%= @name %>! Random: <%= @random %></p>
      RUBY

      mailer_preview "notifier", <<-RUBY
        class NotifierPreview < ActionMailer::Preview
          def foo
            Notifier.foo(params[:name] || "World")
          end
        end
      RUBY

      app("development")

      # Request with parameters
      get "/rails/mailers/notifier/foo?name=Ruby"
      assert_equal 200, last_response.status

      # Extract email_id
      email_id = nil
      assert_select "iframe[src*='email_id']" do |iframe|
        email_id = Rack::Utils.parse_nested_query(URI.parse(iframe.first["src"]).query)["email_id"]
      end

      # Get HTML version
      get "/rails/mailers/notifier/foo?name=Ruby&part=text%2Fhtml&email_id=#{email_id}"
      html_content = last_response.body
      html_random = html_content.match(/Random: (\d+)/)[1]

      # Get plain text version with same email_id
      get "/rails/mailers/notifier/foo?name=Ruby&part=text%2Fplain&email_id=#{email_id}"
      text_content = last_response.body
      text_random = text_content.match(/Random: (\d+)/)[1]

      # Random values should match due to persistence
      assert_equal html_random, text_random

      # Both should contain the correct name
      assert_match "Hello, Ruby!", html_content
      assert_match "Hello, Ruby!", text_content
    end

    private
      def build_app
        super
        app_file "config/routes.rb", "Rails.application.routes.draw do; end"
        app_dir "test/mailers/previews"
      end

      def document_root_element
        Nokogiri::HTML5.parse(last_response.body)
      end

      def mailer(name, contents)
        app_file("app/mailers/#{name}.rb", contents)
      end

      def mailer_preview(name, contents)
        app_file("test/mailers/previews/#{name}_preview.rb", contents)
      end

      def html_template(name, contents)
        app_file("app/views/#{name}.html.erb", contents)
      end

      def text_template(name, contents)
        app_file("app/views/#{name}.text.erb", contents)
      end

      def image_file(name, contents)
        app_file("public/images/#{name}", Base64.strict_decode64(contents), "wb")
      end
  end
end
