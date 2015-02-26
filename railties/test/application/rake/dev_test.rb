require 'isolation/abstract_unit'

module ApplicationTests
  module RakeTests
    class RakeDevTest < ActiveSupport::TestCase

      def setup
        build_app
        boot_rails
      end

      def teardown
        teardown_app
      end

      test 'dev:cache creates and deletes file and outputs message' do
        Dir.chdir(app_path) do
          output = `rake dev:cache`
          assert File.exist?('tmp/caching-dev.txt')
          assert_match(/Development mode is now being cached/, output)
          output = `rake dev:cache`
          assert !File.exist?('tmp/caching-dev.txt')
          assert_match(/Development mode is no longer being cached/, output)
        end
      end
    end
  end
end
