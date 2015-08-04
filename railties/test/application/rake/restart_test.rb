require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeRestartTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
        boot_rails
      end

      def teardown
        teardown_app
      end

      test 'rake restart touches tmp/restart.txt' do
        Dir.chdir(app_path) do
          `rake restart`
          assert File.exist?("tmp/restart.txt")

          prev_mtime = File.mtime("tmp/restart.txt")
          sleep(1)
          `rake restart`
          curr_mtime = File.mtime("tmp/restart.txt")
          assert_not_equal prev_mtime, curr_mtime
        end
      end

      test 'rake restart should work even if tmp folder does not exist' do
        Dir.chdir(app_path) do
          FileUtils.remove_dir('tmp')
          `rake restart`
          assert File.exist?('tmp/restart.txt')
        end
      end
    end
  end
end
