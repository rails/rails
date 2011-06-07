require 'fileutils'

require 'test/unit'
require 'rubygems'

# TODO: Remove setting this magic constant
RAILS_FRAMEWORK_ROOT = File.expand_path("#{File.dirname(__FILE__)}/../../..")

# These files do not require any others and are needed
# to run the tests
require "#{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/testing/isolation"
require "#{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/testing/declarative"
require "#{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/core_ext/kernel/reporting"
require "#{RAILS_FRAMEWORK_ROOT}/railties/lib/rails/generators/test_case"

module RailtiesTests
  class GeneratorTest < Rails::Generators::TestCase
    include ActiveSupport::Testing::Isolation

    TMP_PATH = File.expand_path(File.join(File.dirname(__FILE__), *%w[.. .. tmp]))
    self.destination_root = File.join(TMP_PATH, "foo_bar")

    def tmp_path(*args)
      File.join(TMP_PATH, *args)
    end

    def engine_path
      tmp_path('foo_bar')
    end

    def bundled_rails(cmd)
      `bundle exec rails #{cmd}`
    end

    def rails(cmd)
      environment = File.expand_path('../../../../load_paths', __FILE__)
      if File.exist?("#{environment}.rb")
        require_environment = "-r #{environment}"
      end
      `#{Gem.ruby} #{require_environment} #{RAILS_FRAMEWORK_ROOT}/bin/rails #{cmd}`
    end

    def build_engine
      FileUtils.mkdir_p(engine_path)
      FileUtils.rm_r(engine_path)

      rails("plugin new #{engine_path} --full --mountable")

      Dir.chdir(engine_path) do
        File.open("Gemfile", "w") do |f|
          f.write <<-GEMFILE.gsub(/^ {12}/, '')
            source "http://rubygems.org"

            gem 'rails', :path => '#{RAILS_FRAMEWORK_ROOT}'
            gem 'sqlite3'

            if RUBY_VERSION < '1.9'
              gem "ruby-debug", ">= 0.10.3"
            end
          GEMFILE
        end
      end
    end

    def setup
      build_engine
    end

    def test_controllers_are_correctly_namespaced
      Dir.chdir(engine_path) do
        bundled_rails("g controller topics")
        assert_file "app/controllers/foo_bar/topics_controller.rb", /FooBar::TopicsController/
      end
    end

    def test_models_are_correctly_namespaced
      Dir.chdir(engine_path) do
        bundled_rails("g model topic")
        assert_file "app/models/foo_bar/topic.rb", /FooBar::Topic/
      end
    end

    def test_helpers_are_correctly_namespaced
      Dir.chdir(engine_path) do
        bundled_rails("g helper topics")
        assert_file "app/helpers/foo_bar/topics_helper.rb", /FooBar::TopicsHelper/
      end
    end
  end
end
