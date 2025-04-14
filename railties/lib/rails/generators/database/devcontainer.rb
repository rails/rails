# frozen_string_literal: true

module Rails
  module Generators
    class Devcontainer
      module MySQL
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
      end

      module MariaDB
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

      def service
        raise NotImplementedError
      end

      class MySQL2 < Devcontainer
        include MySQL
      end

      class PostgreSQL < Devcontainer
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
      end

      class Trilogy < Devcontainer
        include MySQL
      end

      class MariaDBMySQL2 < MySQL2
        include MariaDB
      end

      class MariaDBTrilogy < Trilogy
        include MariaDB
      end

      class Null < Devcontainer
        def service; end
      end

      class SQLite3 < Null; end
    end
  end
end
