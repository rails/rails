require "isolation/abstract_unit"
begin
  require "pty"
rescue LoadError
end

module ApplicationTests
  class DBConsoleTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_use_value_defined_in_environment_file_in_database_yml
      skip "PTY unavailable" unless available_pty?
      Dir.chdir(app_path) do
        app_file "config/database.yml", <<-YAML
          development:
             database: <%= Rails.application.config.database %>
             adapter: sqlite3
             pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
             timeout: 5000
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "db/development.sqlite3"
          end
        RUBY
      end

      master, slave = PTY.open
      spawn_dbconsole(slave)
      assert_output("sqlite>", master)
    ensure
      master.puts ".exit"
    end

    private
      def spawn_dbconsole(fd)
        Process.spawn("#{app_path}/bin/rails dbconsole", in: fd, out: fd, err: fd)
      end

      def assert_output(expected, io, timeout = 5)
        timeout = Time.now + timeout

        output = ""
        until output.include?(expected) || Time.now > timeout
          if IO.select([io], [], [], 0.1)
            output << io.read(1)
          end
        end

        assert_includes output, expected, "#{expected.inspect} expected, but got:\n\n#{output}"
      end

      def available_pty?
        defined?(PTY) && PTY.respond_to?(:open)
      end
  end
end
