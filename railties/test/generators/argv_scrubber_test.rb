# frozen_string_literal: true

require "active_support/test_case"
require "active_support/testing/autorun"
require "rails/generators/rails/app/app_generator"
require "tempfile"
require "fileutils"
require "env_helpers"

module Rails
  module Generators
    class ARGVScrubberTest < ActiveSupport::TestCase # :nodoc:
      # Future people who read this... These tests are just to surround the
      # current behavior of the ARGVScrubber, they do not mean that the class
      # *must* act this way, I just want to prevent regressions.
      include EnvHelpers

      def test_version
        ["-v", "--version"].each do |str|
          scrubber = ARGVScrubber.new [str]
          output    = nil
          exit_code = nil
          scrubber.extend(Module.new {
            define_method(:puts) { |string| output = string }
            define_method(:exit) { |code| exit_code = code }
          })
          scrubber.prepare!
          assert_equal "Rails #{Rails::VERSION::STRING}", output
          assert_equal 0, exit_code
        end
      end

      def test_default_help
        argv = ["zomg", "how", "are", "you"]
        scrubber = ARGVScrubber.new argv
        args = scrubber.prepare!
        assert_equal ["--help"] + argv.drop(1), args
      end

      def test_prepare_returns_args
        scrubber = ARGVScrubber.new ["hi mom"]
        args = scrubber.prepare!
        assert_equal "--help", args.first
      end

      def test_no_mutations
        scrubber = ARGVScrubber.new ["hi mom"].freeze
        args = scrubber.prepare!
        assert_equal "--help", args.first
      end

      def test_new_command_no_rc
        scrubber = Class.new(ARGVScrubber) {
          def self.default_rc_file
            File.join(Dir.tmpdir, "whatever")
          end
        }.new ["new"]
        args = scrubber.prepare!
        assert_equal [], args
      end

      def test_default_rc_file_with_xdg_config_home
        Dir.mktmpdir do |dir|
          rc_file = File.join(dir, "rails/railsrc")
          FileUtils.mkdir_p(File.dirname(rc_file))
          FileUtils.touch(rc_file)
          switch_env("XDG_CONFIG_HOME", dir) do
            assert_equal rc_file, ARGVScrubber.default_rc_file
          end
        end
      end

      def test_new_homedir_rc
        file = Tempfile.new "myrcfile"
        file.puts "--hello-world"
        file.flush

        message = nil
        scrubber = Class.new(ARGVScrubber) {
          define_singleton_method(:default_rc_file) do
            file.path
          end
          define_method(:puts) { |msg| message = msg }
        }.new ["new"]
        args = scrubber.prepare!
        assert_equal ["--hello-world"], args
        assert_match "hello-world", message
        assert_match file.path, message
      ensure
        file.close
        file.unlink
      end

      def test_rc_whitespace_separated
        file = Tempfile.new "myrcfile"
        file.puts "--hello --world"
        file.flush

        scrubber = Class.new(ARGVScrubber) {
          define_method(:puts) { |msg| }
        }.new ["new", "--rc=#{file.path}"]
        args = scrubber.prepare!
        assert_equal ["--hello", "--world"], args
      ensure
        file.close
        file.unlink
      end

      def test_new_rc_option
        file = Tempfile.new "myrcfile"
        file.puts "--hello-world"
        file.flush

        message = nil
        scrubber = Class.new(ARGVScrubber) {
          define_method(:puts) { |msg| message = msg }
        }.new ["new", "--rc=#{file.path}"]
        args = scrubber.prepare!
        assert_equal ["--hello-world"], args
        assert_match "hello-world", message
        assert_match file.path, message
      ensure
        file.close
        file.unlink
      end

      def test_new_rc_option_and_custom_options
        file = Tempfile.new "myrcfile"
        file.puts "--hello"
        file.puts "--world"
        file.flush

        scrubber = Class.new(ARGVScrubber) {
          define_method(:puts) { |msg| }
        }.new ["new", "tenderapp", "--love", "--rc=#{file.path}"]

        args = scrubber.prepare!
        assert_equal ["tenderapp", "--hello", "--world", "--love"], args
      ensure
        file.close
        file.unlink
      end

      def test_no_rc
        scrubber = ARGVScrubber.new ["new", "--no-rc"]
        args = scrubber.prepare!
        assert_equal [], args
      end
    end
  end
end
