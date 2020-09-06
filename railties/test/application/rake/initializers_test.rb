# frozen_string_literal: true

require 'isolation/abstract_unit'

module ApplicationTests
  module RakeTests
    class RakeInitializersTest < ActiveSupport::TestCase
      setup :build_app
      teardown :teardown_app

      test '`rake initializers` prints out defined initializers invoked by Rails' do
        capture(:stderr) do
          initial_output = run_rake_initializers
          initial_output_length = initial_output.split("\n").length

          assert_operator initial_output_length, :>, 0
          assert_not initial_output.include?('set_added_test_module')

          add_to_config <<-RUBY
            initializer(:set_added_test_module) { }
          RUBY

          final_output = run_rake_initializers
          final_output_length = final_output.split("\n").length

          assert_equal 1, (final_output_length - initial_output_length)
          assert final_output.include?('set_added_test_module')
        end
      end

      test '`rake initializers` outputs a deprecation warning' do
        add_to_env_config('development', 'config.active_support.deprecation = :stderr')

        stderr = capture(:stderr) { run_rake_initializers }
        assert_match(/DEPRECATION WARNING: Using `bin\/rake initializers` is deprecated and will be removed in Rails 6.1/, stderr)
      end

      private
        def run_rake_initializers
          Dir.chdir(app_path) { `bin/rake initializers` }
        end
    end
  end
end
