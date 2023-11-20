# frozen_string_literal: true

module Rails
  module Generators
    module Database # :nodoc:
      JDBC_DATABASES = %w( jdbcmysql jdbcsqlite3 jdbcpostgresql jdbc )
      DATABASES = %w( mysql mysql2 trilogy postgresql sqlite3 oracle sqlserver ) + JDBC_DATABASES

      def initialize(*)
        super
        convert_database_option_for_jruby
      end

      def gem_for_database(database = options[:database])
        case database
        when "mysql","trilogy" then ["trilogy", ["~> 0.5"]]
        when "mysql2"          then ["mysql2", ["~> 0.5"]]
        when "postgresql"      then ["pg", ["~> 1.1"]]
        when "sqlite3"         then ["sqlite3", ["~> 1.4"]]
        when "oracle"          then ["activerecord-oracle_enhanced-adapter", nil]
        when "sqlserver"       then ["activerecord-sqlserver-adapter", nil]
        when "jdbcmysql"       then ["activerecord-jdbcmysql-adapter", nil]
        when "jdbcsqlite3"     then ["activerecord-jdbcsqlite3-adapter", nil]
        when "jdbcpostgresql"  then ["activerecord-jdbcpostgresql-adapter", nil]
        when "jdbc"            then ["activerecord-jdbc-adapter", nil]
        else [database, nil]
        end
      end

      def docker_for_database_build(database = options[:database])
        case database
        when "mysql2"                      then "build-essential git default-libmysqlclient-dev"
        when "postgresql"                  then "build-essential git libpq-dev"
        when "sqlite3", "mysql", "trilogy" then "build-essential git"
        else nil
        end
      end

      def docker_for_database_deploy(database = options[:database])
        case database
        when "mysql", "mysql2", "trilogy" then "curl libvips default-mysql-client"
        when "postgresql"                 then "curl libvips postgresql-client"
        when "sqlite3"                    then "curl libvips libsqlite3-0"
        else nil
        end
      end

      def convert_database_option_for_jruby
        if defined?(JRUBY_VERSION)
          opt = options.dup
          case opt[:database]
          when "postgresql" then opt[:database] = "jdbcpostgresql"
          when "mysql"      then opt[:database] = "jdbcmysql"
          when "sqlite3"    then opt[:database] = "jdbcsqlite3"
          end
          self.options = opt.freeze
        end
      end

      def build_package_for_database(database = options[:database])
        case database
        when "mysql2" then "default-libmysqlclient-dev"
        when "postgresql" then "libpq-dev"
        else nil
        end
      end

      def deploy_package_for_database(database = options[:database])
        case database
        when "mysql", "mysql2", "trilogy" then "default-mysql-client"
        when "postgresql" then "postgresql-client"
        when "sqlite3" then "libsqlite3-0"
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
    end
  end
end
