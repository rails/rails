require "isolation/abstract_unit"
begin
  require "pty"
rescue LoadError
end

module ApplicationTests
  class DBConsoleTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      skip "PTY unavailable" unless available_pty?

      build_app
    end

    def teardown
      teardown_app
    end

    def test_use_value_defined_in_environment_file_in_database_yml
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

    def test_respect_environment_option
      Dir.chdir(app_path) do
        app_file "config/database.yml", <<-YAML
          default: &default
            adapter: sqlite3
            pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
            timeout: 5000

          development:
            <<: *default
            database: db/development.sqlite3

          production:
            <<: *default
            database: db/production.sqlite3
        YAML
      end

      master, slave = PTY.open
      spawn_dbconsole(slave, "-e production")
      assert_output("sqlite>", master)

      master.puts ".databases"
      assert_output("production.sqlite3", master)
    ensure
      master.puts ".exit"
    end

    private
      def spawn_dbconsole(fd, options = nil)
        Process.spawn("#{app_path}/bin/rails dbconsole #{options}", in: fd, out: fd, err: fd)
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
