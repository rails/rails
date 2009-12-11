require "isolation/abstract_unit"

module ApplicationTests
  class InitializerTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    test "the application root is set correctly" do
      require "#{app_path}/config/environment"
      assert_equal Pathname.new(app_path), Rails.application.root
    end

    test "the application root can be set" do
      FileUtils.mkdir_p("#{app_path}/hello")
      add_to_config <<-RUBY
        config.frameworks = []
        config.root = '#{app_path}/hello'
      RUBY
      require "#{app_path}/config/environment"
      assert_equal Pathname.new("#{app_path}/hello"), Rails.application.root
    end

    test "the application root is detected as where config.ru is located" do
      add_to_config <<-RUBY
        config.frameworks = []
      RUBY
      FileUtils.mv "#{app_path}/config.ru", "#{app_path}/config/config.ru"
      require "#{app_path}/config/environment"
      assert_equal Pathname.new("#{app_path}/config"), Rails.application.root
    end

    test "the application root is Dir.pwd if there is no config.ru" do
      File.delete("#{app_path}/config.ru")
      add_to_config <<-RUBY
        config.frameworks = []
      RUBY

      Dir.chdir("#{app_path}/app") do
        require "#{app_path}/config/environment"
        assert_equal Pathname.new("#{app_path}/app"), Rails.application.root
      end
    end

    test "config.active_support.bare does not require all of ActiveSupport" do
      add_to_config "config.frameworks = []; config.active_support.bare = true"

      Dir.chdir("#{app_path}/app") do
        require "#{app_path}/config/environment"
        assert_raises(NoMethodError) { 1.day }
      end
    end
  end
end
