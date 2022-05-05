# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class I18nTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      FileUtils.rm_rf "#{app_path}/config/environments"
      require "rails/all"
    end

    def teardown
      teardown_app
    end

    def load_app
      require "#{app_path}/config/environment"
    end

    def app
      @app ||= Rails.application
    end

    def assert_fallbacks(fallbacks)
      fallbacks.each do |locale, expected|
        actual = I18n.fallbacks[locale]
        assert_equal expected, actual, "expected fallbacks for #{locale.inspect} to be #{expected.inspect}, but were #{actual.inspect}"
      end
    end

    def assert_no_fallbacks
      assert_not_includes I18n.backend.class.included_modules, I18n::Backend::Fallbacks
    end

    # Locales
    test "setting another default locale" do
      add_to_config <<-RUBY
        config.i18n.default_locale = :de
      RUBY

      load_app
      assert_equal :de, I18n.default_locale
    end

    # Load paths
    test "no config locales directory present should return empty load path" do
      FileUtils.rm_rf "#{app_path}/config/locales"
      load_app
      assert_equal [], Rails.application.config.i18n.load_path
    end

    test "locale files should be added to the load path" do
      app_file "config/another_locale.yml", "en:\nfoo: ~"

      add_to_config <<-RUBY
        config.i18n.load_path << config.root.join("config/another_locale.yml").to_s
      RUBY

      load_app
      assert_equal [
        "#{app_path}/config/locales/en.yml", "#{app_path}/config/another_locale.yml"
      ], Rails.application.config.i18n.load_path

      assert_includes I18n.load_path, "#{app_path}/config/locales/en.yml"
      assert_includes I18n.load_path, "#{app_path}/config/another_locale.yml"
    end

    test "load_path is populated before eager loaded models" do
      add_to_config <<-RUBY
        config.enable_reloading = false
      RUBY

      app_file "config/locales/en.yml", <<-YAML
en:
  foo: "1"
      YAML

      app_file "app/models/foo.rb", <<-RUBY
        class Foo < ActiveRecord::Base
          @foo = I18n.t(:foo)
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/i18n',   :to => lambda { |env| [200, {}, [Foo.instance_variable_get('@foo')]] }
        end
      RUBY

      require "rack/test"
      extend Rack::Test::Methods
      load_app

      get "/i18n"
      assert_equal "1", last_response.body
    end

    test "locales are reloaded if they change between requests" do
      add_to_config <<-RUBY
        config.enable_reloading = true
      RUBY

      app_file "config/locales/en.yml", <<-YAML
en:
  foo: "1"
      YAML

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/i18n',   :to => lambda { |env| [200, {}, [I18n.t(:foo)]] }
        end
      RUBY

      require "rack/test"
      extend Rack::Test::Methods
      load_app

      get "/i18n"
      assert_equal "1", last_response.body

      # Wait a full second so we have time for changes to propagate
      sleep(1)

      app_file "config/locales/en.yml", <<-YAML
en:
  foo: "2"
      YAML

      get "/i18n"
      assert_equal "2", last_response.body
    end

    test "new locale files are loaded" do
      add_to_config <<-RUBY
        config.enable_reloading = true
      RUBY

      app_file "config/locales/en.yml", <<-YAML
en:
  foo: "1"
      YAML

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/i18n',   :to => lambda { |env| [200, {}, [I18n.t(:foo)]] }
        end
      RUBY

      require "rack/test"
      extend Rack::Test::Methods
      load_app

      get "/i18n"
      assert_equal "1", last_response.body

      # Wait a full second so we have time for changes to propagate
      sleep(1)

      remove_file "config/locales/en.yml"
      app_file "config/locales/custom.en.yml", <<-YAML
en:
  foo: "2"
      YAML

      get "/i18n"
      assert_equal "2", last_response.body
    end

    test "I18n.load_path is reloaded" do
      add_to_config <<-RUBY
        config.enable_reloading = true
      RUBY

      app_file "config/locales/en.yml", <<-YAML
en:
  foo: "1"
      YAML

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/i18n',   :to => lambda { |env| [200, {}, [I18n.load_path.inspect]] }
        end
      RUBY

      require "rack/test"
      extend Rack::Test::Methods
      load_app

      get "/i18n"

      assert_match "en.yml", last_response.body

      # Wait a full second so we have time for changes to propagate
      sleep(1)

      app_file "config/locales/fr.yml", <<-YAML
fr:
  foo: "2"
      YAML

      get "/i18n"
      assert_match "fr.yml", last_response.body
      assert_match "en.yml", last_response.body
    end

    # Fallbacks
    test "not using config.i18n.fallbacks does not initialize I18n.fallbacks" do
      I18n.backend = Class.new(I18n::Backend::Simple).new
      load_app
      assert_no_fallbacks
    end

    test "config.i18n.fallbacks = true initializes I18n.fallbacks with default settings" do
      I18n::Railtie.config.i18n.fallbacks = true
      load_app
      assert_includes I18n.backend.class.included_modules, I18n::Backend::Fallbacks
      assert_fallbacks de: [:de, :en]
    end

    test "config.i18n.fallbacks = true initializes I18n.fallbacks with default settings even when backend changes" do
      I18n::Railtie.config.i18n.fallbacks = true
      I18n::Railtie.config.i18n.backend = Class.new(I18n::Backend::Simple).new
      load_app
      assert_includes I18n.backend.class.included_modules, I18n::Backend::Fallbacks
      assert_fallbacks de: [:de, :en]
    end

    test "config.i18n.fallbacks.defaults = [:'en-US'] initializes fallbacks with en-US as a fallback default" do
      I18n::Railtie.config.i18n.fallbacks.defaults = [:'en-US']
      load_app
      assert_fallbacks de: [:de, :'en-US', :en]
    end

    test "config.i18n.fallbacks.map = { :ca => :'es-ES' } initializes fallbacks with a mapping ca => es-ES" do
      I18n::Railtie.config.i18n.fallbacks.map = { ca: :'es-ES' }
      load_app
      assert_fallbacks ca: [:ca, :"es-ES", :es]
    end

    test "[shortcut] config.i18n.fallbacks = [:'en-US'] initializes fallbacks with en-US as a fallback default" do
      I18n::Railtie.config.i18n.fallbacks = [:'en-US']
      load_app
      assert_fallbacks de: [:de, :'en-US', :en]
    end

    test "[shortcut] config.i18n.fallbacks = [{ :ca => :'es-ES' }] initializes fallbacks with a mapping ca => es-ES" do
      I18n::Railtie.config.i18n.fallbacks = [{ ca: :'es-ES' }]
      load_app
      assert_fallbacks ca: [:ca, :"es-ES", :es]
    end

    test "[shortcut] config.i18n.fallbacks = [:'en-US', { :ca => :'es-ES' }] initializes fallbacks with the given arguments" do
      I18n::Railtie.config.i18n.fallbacks = [:'en-US', { ca: :'es-ES' }]
      load_app
      assert_fallbacks ca: [:ca, :"es-ES", :es, :'en-US', :en]
    end

    test "[shortcut] config.i18n.fallbacks = { ca: :en } initializes fallbacks with a mapping ca => :en" do
      I18n::Railtie.config.i18n.fallbacks = { ca: :en }
      load_app
      assert_fallbacks ca: [:ca, :en]
    end

    test "disable config.i18n.enforce_available_locales" do
      add_to_config <<-RUBY
        config.i18n.enforce_available_locales = false
        config.i18n.default_locale = :fr
      RUBY

      load_app
      assert_equal false, I18n.enforce_available_locales

      assert_nothing_raised do
        I18n.locale = :es
      end
    end

    test "default config.i18n.enforce_available_locales does not override I18n.enforce_available_locales" do
      I18n.enforce_available_locales = false

      add_to_config <<-RUBY
        config.i18n.default_locale = :fr
      RUBY

      load_app
      assert_equal false, I18n.enforce_available_locales

      assert_nothing_raised do
        I18n.locale = :es
      end
    end
  end
end
