# frozen_string_literal: true

require 'isolation/abstract_unit'

module ApplicationTests
  module RakeTests
    class RakeRestartTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
      end

      def teardown
        teardown_app
      end

      test 'rails restart touches tmp/restart.txt' do
        Dir.chdir(app_path) do
          rails 'restart'
          assert File.exist?('tmp/restart.txt')

          prev_mtime = File.mtime('tmp/restart.txt')
          sleep(1)
          rails 'restart'
          curr_mtime = File.mtime('tmp/restart.txt')
          assert_not_equal prev_mtime, curr_mtime
        end
      end

      test 'rails restart should work even if tmp folder does not exist' do
        Dir.chdir(app_path) do
          FileUtils.remove_dir('tmp')
          rails 'restart'
          assert File.exist?('tmp/restart.txt')
        end
      end
    end
  end
end
