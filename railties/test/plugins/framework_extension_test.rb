require "isolation/abstract_unit"

module PluginsTest
  class FrameworkExtensionTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf("#{app_path}/config/environments")
      require "rails/all"
    end

    test "rake_tasks block is executed when MyApp.load_tasks is called" do
      $ran_block = false

      class MyTie < Rails::Railtie
        rake_tasks do
          $ran_block = true
        end
      end

      require "#{app_path}/config/environment"

      assert !$ran_block
      require 'rake'
      require 'rake/testtask'
      require 'rake/rdoctask'

      AppTemplate::Application.load_tasks
      assert $ran_block
    end

    test "generators block is executed when MyApp.load_generators is called" do
      $ran_block = false

      class MyTie < Rails::Railtie
        generators do
          $ran_block = true
        end
      end

      require "#{app_path}/config/environment"

      assert !$ran_block
      AppTemplate::Application.load_generators
      assert $ran_block
    end
  end

  class ActiveRecordExtensionTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf("#{app_path}/config/environments")
    end

    test "active_record extensions are applied to ActiveRecord" do
      add_to_config "config.active_record.table_name_prefix = 'tbl_'"

      require "#{app_path}/config/environment"

      assert_equal 'tbl_', ActiveRecord::Base.table_name_prefix
    end
  end
end