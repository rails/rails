require "isolation/abstract_unit"

module ApplicationTests
  class I18nTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    # i18n
    test "setting another default locale" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.i18n.default_locale = :de
      RUBY
      require "#{app_path}/config/environment"

      assert_equal :de, I18n.default_locale
    end

    test "no config locales dir present should return empty load path" do
      FileUtils.rm_rf "#{app_path}/config/locales"
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY
      require "#{app_path}/config/environment"

      assert_equal [], Rails.application.config.i18n.load_path
    end

    test "config locales dir present should be added to load path" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY

      require "#{app_path}/config/environment"
      assert_equal ["#{app_path}/config/locales/en.yml"],  Rails.application.config.i18n.load_path
    end

    test "config defaults should be added with config settings" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.i18n.load_path << "my/other/locale.yml"
      RUBY
      require "#{app_path}/config/environment"

      assert_equal [
        "#{app_path}/config/locales/en.yml", "my/other/locale.yml"
      ], Rails.application.config.i18n.load_path
    end
  end
end