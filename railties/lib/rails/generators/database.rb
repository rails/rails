# frozen_string_literal: true

module Rails
  module Generators
    class Database
      DATABASES = %w( mysql trilogy postgresql sqlite3 )

      class << self
        def build(database_name)
          case database_name
          when "mysql" then MySQL.new
          when "postgresql" then PostgreSQL.new
          when "trilogy" then MariaDB.new
          when "sqlite3" then SQLite3.new
          else Null.new
          end
        end

        def all
          @all ||= [
            MySQL.new,
            PostgreSQL.new,
            MariaDB.new,
            SQLite3.new,
          ]
        end
      end

      def name
        raise NotImplementedError
      end

      def service
        raise NotImplementedError
      end

      def port
        raise NotImplementedError
      end

      def feature_name
        raise NotImplementedError
      end

      def gem
        raise NotImplementedError
      end

      def base_package
        raise NotImplementedError
      end

      def build_package
        raise NotImplementedError
      end

      def socket; end
      def host; end

      def feature
        return unless feature_name

        { feature_name => {} }
      end

      def volume
        return unless service

        "#{name}-data"
      end

      module MySqlSocket
        def socket
          @socket ||= [
            "/tmp/mysql.sock",                        # default
            "/var/run/mysqld/mysqld.sock",            # debian/gentoo
            "/var/tmp/mysql.sock",                    # freebsd
            "/var/lib/mysql/mysql.sock",              # fedora
            "/opt/local/lib/mysql/mysql.sock",        # fedora
            "/opt/local/var/run/mysqld/mysqld.sock",  # mac + darwinports + mysql
            "/opt/local/var/run/mysql4/mysqld.sock",  # mac + darwinports + mysql4
            "/opt/local/var/run/mysql5/mysqld.sock",  # mac + darwinports + mysql5
            "/opt/lampp/var/mysql/mysql.sock"         # xampp for linux
          ].find { |f| File.exist?(f) } unless Gem.win_platform?
        end

        def host
          "localhost"
        end
      end

      class MySQL < Database
        include MySqlSocket

        def name
          "mysql"
        end

        def service
          {
            "image" => "mysql/mysql-server:8.0",
            "restart" => "unless-stopped",
            "environment" => {
              "MYSQL_ALLOW_EMPTY_PASSWORD" => "true",
              "MYSQL_ROOT_HOST" => "%"
            },
            "volumes" => ["mysql-data:/var/lib/mysql"],
            "networks" => ["default"],
          }
        end

        def port
          3306
        end

        def gem
          ["mysql2", ["~> 0.5"]]
        end

        def base_package
          "default-mysql-client"
        end

        def build_package
          "default-libmysqlclient-dev"
        end

        def feature_name
          "ghcr.io/rails/devcontainer/features/mysql-client"
        end
      end

      class PostgreSQL < Database
        def name
          "postgres"
        end

        def service
          {
            "image" => "postgres:16.1",
            "restart" => "unless-stopped",
            "networks" => ["default"],
            "volumes" => ["postgres-data:/var/lib/postgresql/data"],
            "environment" => {
              "POSTGRES_USER" => "postgres",
              "POSTGRES_PASSWORD" => "postgres"
            }
          }
        end

        def port
          5432
        end

        def gem
          ["pg", ["~> 1.1"]]
        end

        def base_package
          "postgresql-client"
        end

        def build_package
          "libpq-dev"
        end

        def feature_name
          "ghcr.io/rails/devcontainer/features/postgres-client"
        end
      end

      class MariaDB < Database
        include MySqlSocket

        def name
          "mariadb"
        end

        def service
          {
            "image" => "mariadb:10.5",
            "restart" => "unless-stopped",
            "networks" => ["default"],
            "volumes" => ["mariadb-data:/var/lib/mysql"],
            "environment" => {
              "MARIADB_ALLOW_EMPTY_ROOT_PASSWORD" => "true",
            },
          }
        end

        def port
          3306
        end

        def gem
          ["trilogy", ["~> 2.7"]]
        end

        def base_package
          nil
        end

        def build_package
          nil
        end

        def feature_name
          nil
        end
      end

      class SQLite3 < Database
        def name
          "sqlite3"
        end

        def service
          nil
        end

        def port
          nil
        end

        def gem
          ["sqlite3", [">= 1.4"]]
        end

        def base_package
          "sqlite3"
        end

        def build_package
          nil
        end

        def feature_name
          "ghcr.io/rails/devcontainer/features/sqlite3"
        end
      end

      class Null < Database
        def name; end
        def service; end
        def port; end
        def volume; end
        def base_package; end
        def build_package; end
        def feature_name; end
      end
    end
  end
end
