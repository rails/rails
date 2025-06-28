# frozen_string_literal: true

module Rails
  module Generators
    class Ci
      module MySQL
        def service
          {
            "image" => "mysql",
            "env" => {
              "MYSQL_ALLOW_EMPTY_PASSWORD" => true
            },
            "ports" => ["3306:3306"],
            "options" => "--health-cmd=\"mysqladmin ping\" --health-interval=10s --health-timeout=5s --health-retries=3"
          }
        end
      end

      module MariaDB
        def service; end

        def database_url; end
      end

      def service; end

      def database_url; end

      class MySQL2 < Ci
        include MySQL

        def database_url
          "mysql2://127.0.0.1:3306"
        end
      end

      class Trilogy < Ci
        include MySQL

        def database_url
          "trilogy://127.0.0.1:3306"
        end
      end

      class PostgreSQL < Ci
        def service
          {
            "image" => "postgres",
            "env" => {
              "POSTGRES_USER" => "postgres",
              "POSTGRES_PASSWORD" => "postgres"
            },
            "ports" => ["5432:5432"],
            "options" => "--health-cmd=\"pg_isready\" --health-interval=10s --health-timeout=5s --health-retries=3"
          }
        end

        def database_url
          "postgres://postgres:postgres@localhost:5432"
        end
      end


      class MariaDBMySQL2 < MySQL2
        include MariaDB
      end

      class MariaDBTrilogy < Trilogy
        include MariaDB
      end

      class Null < Ci
        def service; end
        def database_url; end
      end

      class SQLite3 < Null; end
    end
  end
end
