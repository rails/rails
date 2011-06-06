# require 'isolation/abstract_unit'

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

module EngineTests
  class ControllerGenerator < Rails::Generators::TestCase
    include ActiveSupport::Testing::Isolation
    
    TMP_PATH = File.expand_path(File.join(File.dirname(__FILE__), *%w[.. .. tmp]))
    self.destination_root = File.join(TMP_PATH, "foo_bar")

    def tmp_path(*args)
      File.join(TMP_PATH, *args)
    end
    
    def engine_path
      tmp_path('foo_bar')
    end
    
    def build_engine
      FileUtils.mkdir_p(engine_path)
      FileUtils.rm_r(engine_path)
      environment = File.expand_path('../../../../load_paths', __FILE__)
      if File.exist?("#{environment}.rb")
        require_environment = "-r #{environment}"
      end
      `#{Gem.ruby} #{require_environment} #{RAILS_FRAMEWORK_ROOT}/bin/rails plugin new #{engine_path} --full --mountable`
    end

    def setup
      build_engine
    end
    
    def test_omg
      Dir.chdir(engine_path) do
        `rails g controller topics`
        assert_file "app/controllers/foo_bar/topics_controller.rb"
      end
    end
  end
end
