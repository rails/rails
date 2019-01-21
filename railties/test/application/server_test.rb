# frozen_string_literal: true

require "isolation/abstract_unit"
require "console_helpers"
require "rails/command"
require "rails/commands/server/server_command"

module ApplicationTests
  class ServerTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
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
        f.puts "require 'bundler/setup'"
      end

      primary, replica = PTY.open
      pid = nil

      begin
        pid = Process.spawn("#{app_path}/bin/rails server -P tmp/dummy.pid", in: replica, out: replica, err: replica)
        assert_output("Listening", primary)

        rails("restart")

        assert_output("Restarting", primary)
        assert_output("Inherited", primary)
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
