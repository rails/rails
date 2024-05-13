# frozen_string_literal: true

module Rails
  module Generators
    module Database # :nodoc:
      DATABASES = %w( mysql trilogy postgresql sqlite3 )

      def gem_for_database(database = options[:database])
        case database
        when "mysql"          then ["mysql2", ["~> 0.5"]]
        when "trilogy"        then ["trilogy", ["~> 2.7"]]
        when "postgresql"     then ["pg", ["~> 1.1"]]
        when "sqlite3"        then ["sqlite3", [">= 1.4"]]
        else [database, nil]
        end
      end

      def docker_for_database_base(database = options[:database])
        case database
        when "mysql"          then "curl default-mysql-client libvips"
        when "trilogy"        then "curl libvips"
        when "postgresql"     then "curl libvips postgresql-client"
        when "sqlite3"        then "curl libsqlite3-0 libvips"
        else nil
        end
      end

      def docker_for_database_build(database = options[:database])
        case database
        when "mysql"          then "build-essential default-libmysqlclient-dev git"
        when "trilogy"        then "build-essential git"
        when "postgresql"     then "build-essential git libpq-dev"
        when "sqlite3"        then "build-essential git"
        else nil
        end
      end

      def base_package_for_database(database = options[:database])
        case database
        when "mysql" then "default-mysql-client"
        when "postgresql" then "postgresql-client"
        when "sqlite3" then "libsqlite3-0"
        else nil
        end
      end

      def build_package_for_database(database = options[:database])
        case database
        when "mysql" then "default-libmysqlclient-dev"
        when "postgresql" then "libpq-dev"
        else nil
        end
      end

      private
        def mysql_socket
          @mysql_socket ||= [
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

        def mysql_database_host
          if options[:skip_devcontainer]
            "localhost"
          else
            "<%= ENV.fetch(\"DB_HOST\") { \"localhost\" } %>"
          end
        end
    end
  end
end
