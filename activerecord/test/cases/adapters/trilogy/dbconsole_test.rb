# frozen_string_literal: true

require "cases/helper"
require "active_support/testing/method_call_assertions"

module ActiveRecord
  module ConnectionAdapters
    class TrilogyDbConsoleTest < ActiveRecord::TrilogyTestCase
      include ActiveSupport::Testing::MethodCallAssertions

      def test_trilogy
        config = make_db_config(adapter: "trilogy", database: "db")

        assert_find_cmd_and_exec_called_with([%w[mysql mysql5], "db"]) do
          TrilogyAdapter.dbconsole(config)
        end
      end

      def test_mysql_full
        config = make_db_config(
          adapter:   "trilogy",
          database:  "db",
          host:      "localhost",
          port:      1234,
          socket:    "socket",
          username:  "user",
          password:  "qwerty",
          encoding:  "UTF-8",
          sslca:     "/path/to/ca-cert.pem",
          sslcert:   "/path/to/client-cert.pem",
          sslcapath: "/path/to/cacerts",
          sslcipher: "DHE-RSA-AES256-SHA",
          sslkey:    "/path/to/client-key.pem",
          ssl_mode:  "VERIFY_IDENTITY"
        )

        args = [
          %w[mysql mysql5],
          "--host=localhost",
          "--port=1234",
          "--socket=socket",
          "--user=user",
          "--default-character-set=UTF-8",
          "--ssl-ca=/path/to/ca-cert.pem",
          "--ssl-cert=/path/to/client-cert.pem",
          "--ssl-capath=/path/to/cacerts",
          "--ssl-cipher=DHE-RSA-AES256-SHA",
          "--ssl-key=/path/to/client-key.pem",
          "--ssl-mode=VERIFY_IDENTITY",
          "-p", "db"
        ]

        assert_find_cmd_and_exec_called_with(args) do
          TrilogyAdapter.dbconsole(config)
        end
      end

      def test_mysql_include_password
        config = make_db_config(adapter: "trilogy", database: "db", username: "user", password: "qwerty")

        assert_find_cmd_and_exec_called_with([%w[mysql mysql5], "--user=user", "--password=qwerty", "db"]) do
          TrilogyAdapter.dbconsole(config, include_password: true)
        end
      end

      private
        def make_db_config(config)
          ActiveRecord::DatabaseConfigurations::HashConfig.new("test", "primary", config)
        end

        def assert_find_cmd_and_exec_called_with(args, &block)
          assert_called_with(TrilogyAdapter, :find_cmd_and_exec, args, &block)
        end
    end
  end
end
