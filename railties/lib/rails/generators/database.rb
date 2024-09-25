# frozen_string_literal: true

module Rails
  module Generators
    class Database
      DATABASES = %w( mysql trilogy postgresql sqlite3 mariadb-mysql mariadb-trilogy )

      module MySQL
        def name
          "mysql"
        end

        def port
          3306
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
          "127.0.0.1"
        end
      end

      module MariaDB
        def name
          "mariadb"
        end

        def port
          3306
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
      end

      class << self
        def build(database_name)
          case database_name
          when "mysql" then MySQL2.new
          when "postgresql" then PostgreSQL.new
          when "trilogy" then Trilogy.new
          when "sqlite3" then SQLite3.new
          when "mariadb-mysql" then MariaDBMySQL2.new
          when "mariadb-trilogy" then MariaDBTrilogy.new
          else Null.new
          end
        end

        def all
          @all ||= [
            MySQL2.new,
            PostgreSQL.new,
            SQLite3.new,
            MariaDBMySQL2.new,
            MariaDBTrilogy.new
          ]
        end
      end

      def name
        raise NotImplementedError
      end

      def template
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

      class MySQL2 < Database
        include MySQL

        def template
          "config/databases/mysql.yml"
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

        def template
          "config/databases/postgresql.yml"
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

      class Trilogy < Database
        include MySQL

        def template
          "config/databases/trilogy.yml"
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

        def template
          "config/databases/sqlite3.yml"
        end

        def service
          nil
        end

        def port
          nil
        end

        def gem
          ["sqlite3", [">= 2.1"]]
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

      class MariaDBMySQL2 < MySQL2
        include MariaDB
      end

      class MariaDBTrilogy < Trilogy
        include MariaDB
      end

      class Null < Database
        def name; end
        def template; end
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
