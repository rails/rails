# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class TmpTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
      end

      def teardown
        teardown_app
      end

      test "tmp:clear clear cache, socket, screenshot, and storage files" do
        Dir.chdir(app_path) do
          FileUtils.mkdir_p("tmp/cache")
          FileUtils.touch("tmp/cache/cache_file")

          FileUtils.mkdir_p("tmp/sockets")
          FileUtils.touch("tmp/sockets/socket_file")

          FileUtils.mkdir_p("tmp/screenshots")
          FileUtils.touch("tmp/screenshots/fail.png")

          FileUtils.mkdir_p("tmp/storage/6h/np")
          FileUtils.touch("tmp/storage/6h/np/6hnp81jvgt42pcfqtlpoy8qshfb0")

          rails "tmp:clear"

          assert_not File.exist?("tmp/cache/cache_file")
          assert_not File.exist?("tmp/sockets/socket_file")
          assert_not File.exist?("tmp/screenshots/fail.png")
          assert_not File.exist?("tmp/storage/6h/np/6hnp81jvgt42pcfqtlpoy8qshfb0")
        end
      end

      test "tmp:clear should work if folder missing" do
        FileUtils.remove_dir("#{app_path}/tmp")
        assert_nothing_raised do
          rails "tmp:clear"
        end
      end
    end
  end
end
