require "isolation/abstract_unit"

module RailtiesTest
  class I18nRailtieTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf("#{app_path}/config/environments")
      require "rails/all"
    end

    def load_app
      require "#{app_path}/config/environment"
    end

    def assert_fallbacks(fallbacks)
      fallbacks.each do |locale, expected|
        actual = I18n.fallbacks[locale]
        assert_equal expected, actual, "expected fallbacks for #{locale.inspect} to be #{expected.inspect}, but were #{actual.inspect}"
      end
    end

    def assert_no_fallbacks
      assert !I18n.backend.class.included_modules.include?(I18n::Backend::Fallbacks)
    end

    test "config.i18n.load_path gets added to I18n.load_path" do
      I18n.load_path = ['existing/path/to/locales']
      I18n::Railtie.config.i18n.load_path = ['new/path/to/locales']
      load_app

      assert I18n.load_path.include?('existing/path/to/locales')
      assert I18n.load_path.include?('new/path/to/locales')
    end

    test "not using config.i18n.fallbacks does not initialize I18n.fallbacks" do
      I18n.backend = Class.new { include I18n::Backend::Base }.new
      load_app
      assert_no_fallbacks
    end

    test "config.i18n.fallbacks = true initializes I18n.fallbacks with default settings" do
      I18n::Railtie.config.i18n.fallbacks = true
      load_app
      assert I18n.backend.class.included_modules.include?(I18n::Backend::Fallbacks)
      assert_fallbacks :de => [:de, :en]
    end

    test "config.i18n.fallbacks = true initializes I18n.fallbacks with default settings even when backend changes" do
      I18n::Railtie.config.i18n.fallbacks = true
      I18n::Railtie.config.i18n.backend = Class.new { include I18n::Backend::Base }.new
      load_app
      assert I18n.backend.class.included_modules.include?(I18n::Backend::Fallbacks)
      assert_fallbacks :de => [:de, :en]
    end

    test "config.i18n.fallbacks.defaults = [:'en-US'] initializes fallbacks with en-US as a fallback default" do
      I18n::Railtie.config.i18n.fallbacks.defaults = [:'en-US']
      load_app
      assert_fallbacks :de => [:de, :'en-US', :en]
    end

    test "config.i18n.fallbacks.map = { :ca => :'es-ES' } initializes fallbacks with a mapping ca => es-ES" do
      I18n::Railtie.config.i18n.fallbacks.map = { :ca => :'es-ES' }
      load_app
      assert_fallbacks :ca => [:ca, :"es-ES", :es, :en]
    end

    test "[shortcut] config.i18n.fallbacks = [:'en-US'] initializes fallbacks with en-US as a fallback default" do
      I18n::Railtie.config.i18n.fallbacks = [:'en-US']
      load_app
      assert_fallbacks :de => [:de, :'en-US', :en]
    end

    test "[shortcut] config.i18n.fallbacks = [{ :ca => :'es-ES' }] initializes fallbacks with a mapping de-AT => de-DE" do
      I18n::Railtie.config.i18n.fallbacks.map = { :ca => :'es-ES' }
      load_app
      assert_fallbacks :ca => [:ca, :"es-ES", :es, :en]
    end

    test "[shortcut] config.i18n.fallbacks = [:'en-US', { :ca => :'es-ES' }] initializes fallbacks with the given arguments" do
      I18n::Railtie.config.i18n.fallbacks = [:'en-US', { :ca => :'es-ES' }]
      load_app
      assert_fallbacks :ca => [:ca, :"es-ES", :es, :'en-US', :en]
    end
  end
end