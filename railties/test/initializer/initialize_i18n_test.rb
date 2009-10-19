require "isolation/abstract_unit"

module InitializerTests
  class InitializeI18nTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      require "rails"
    end

    # test_config_defaults_and_settings_should_be_added_to_i18n_defaults
    test "i18n config defaults and settings should be added to i18n defaults" do
      Rails::Initializer.run do |c|
        c.root = app_path
        c.i18n.load_path << "my/other/locale.yml"
      end
      Rails.initialize!

      #{RAILS_FRAMEWORK_ROOT}/railties/test/fixtures/plugins/engines/engine/config/locales/en.yml
      assert_equal %W(
        #{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activemodel/lib/active_model/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activerecord/lib/active_record/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/actionpack/lib/action_view/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/railties/tmp/app/config/locales/en.yml
        my/other/locale.yml
      ).map { |path| File.expand_path(path) }, I18n.load_path.map { |path| File.expand_path(path) }
    end

    test "i18n finds locale files in engines" do
      app_file "vendor/plugins/engine/init.rb",               ""
      app_file "vendor/plugins/engine/app/models/hellos.rb",  "class Hello ; end"
      app_file "vendor/plugins/engine/lib/omg.rb",            "puts 'omg'"
      app_file "vendor/plugins/engine/config/locales/en.yml", "hello:"

      Rails::Initializer.run do |c|
        c.root = app_path
        c.i18n.load_path << "my/other/locale.yml"
      end
      Rails.initialize!

      #{RAILS_FRAMEWORK_ROOT}/railties/test/fixtures/plugins/engines/engine/config/locales/en.yml
      assert_equal %W(
        #{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activemodel/lib/active_model/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activerecord/lib/active_record/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/actionpack/lib/action_view/locale/en.yml
        #{app_path}/config/locales/en.yml
        my/other/locale.yml
        #{app_path}/vendor/plugins/engine/config/locales/en.yml
      ).map { |path| File.expand_path(path) }, I18n.load_path.map { |path| File.expand_path(path) }
    end
  end
end