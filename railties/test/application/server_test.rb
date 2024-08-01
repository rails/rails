# frozen_string_literal: true

require "isolation/abstract_unit"
require "console_helpers"
require "rails/command"

module ApplicationTests
  class ServerTest < ActiveSupport::TestCase
    include ConsoleHelpers

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "restart rails server with custom pid file path" do
      skip "PTY unavailable" unless available_pty?

      File.open("#{app_path}/config/boot.rb", "w") do |f|
        f.puts "ENV['BUNDLE_GEMFILE'] = '#{Bundler.default_gemfile}'"
        f.puts 'require "bundler/setup"'
      end

      primary, replica = PTY.open
      pid = nil

      Bundler.with_original_env do
        pid = Process.spawn("bin/rails server -b localhost -P tmp/dummy.pid", chdir: app_path, in: replica, out: replica, err: replica)
        assert_output("Listening", primary, 100)

        rails("restart")

        assert_output("Restarting", primary, 100)
        assert_output("Listening", primary, 100)
      ensure
        kill(pid) if pid
      end
    end

    test "run +server+ blocks after the server starts" do
      skip "PTY unavailable" unless available_pty?

      File.open("#{app_path}/config/boot.rb", "w") do |f|
        f.puts "ENV['BUNDLE_GEMFILE'] = '#{Bundler.default_gemfile}'"
        f.puts 'require "bundler/setup"'
      end

      add_to_config(<<~CODE)
        server do
          puts 'Hello world'
        end
      CODE

      primary, replica = PTY.open
      pid = nil

      Bundler.with_original_env do
        pid = Process.spawn("bin/rails server -b localhost", chdir: app_path, in: replica, out: primary, err: replica)
        assert_output("Hello world", primary, 100)
        assert_output("Listening", primary, 100)
      ensure
        kill(pid) if pid
      end
    end

    private
      def kill(pid)
        Process.kill("TERM", pid)
        Process.wait(pid)
      rescue Errno::ESRCH
      end
  end
end
