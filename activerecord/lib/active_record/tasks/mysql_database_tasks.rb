module ActiveRecord
  module Tasks # :nodoc:
    class MySQLDatabaseTasks # :nodoc:
      ACCESS_DENIED_ERROR = 1045

      delegate :connection, :establish_connection, to: ActiveRecord::Base

      def initialize(configuration)
        @configuration = configuration
      end

      def create
        establish_connection configuration_without_database
        connection.create_database configuration["database"], creation_options
        establish_connection configuration
      rescue ActiveRecord::StatementInvalid => error
        if /database exists/ === error.message
          raise DatabaseAlreadyExists
        else
          raise
        end
      rescue error_class => error
        if error.respond_to?(:errno) && error.errno == ACCESS_DENIED_ERROR
          $stdout.print error.message
          establish_connection root_configuration_without_database
          connection.create_database configuration["database"], creation_options
          if configuration["username"] != "root"
            connection.execute grant_statement.gsub(/\s+/, " ").strip
          end
          establish_connection configuration
        else
          $stderr.puts error.inspect
          $stderr.puts "Couldn't create database for #{configuration.inspect}, #{creation_options.inspect}"
          $stderr.puts "(If you set the charset manually, make sure you have a matching collation)" if configuration["encoding"]
        end
      end

      def drop
        establish_connection configuration
        connection.drop_database configuration["database"]
      end

      def purge
        establish_connection configuration
        connection.recreate_database configuration["database"], creation_options
      end

      def charset
        connection.charset
      end

      def collation
        connection.collation
      end

      def structure_dump(filename)
        args = prepare_command_options
        args.concat(["--result-file", "#{filename}"])
        args.concat(["--no-data"])
        args.concat(["--routines"])
        args.concat(["--skip-comments"])
        args.concat(["#{configuration['database']}"])

        run_cmd("mysqldump", args, "dumping")
      end

      def structure_load(filename)
        args = prepare_command_options
        args.concat(["--execute", %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}])
        args.concat(["--database", "#{configuration['database']}"])

        run_cmd("mysql", args, "loading")
      end

      private

      def configuration
        @configuration
      end

      def configuration_without_database
        configuration.merge("database" => nil)
      end

      def creation_options
        Hash.new.tap do |options|
          options[:charset]     = configuration["encoding"]   if configuration.include? "encoding"
          options[:collation]   = configuration["collation"]  if configuration.include? "collation"
        end
      end

      def error_class
        if configuration["adapter"].include?("jdbc")
          require "active_record/railties/jdbcmysql_error"
          ArJdbcMySQL::Error
        elsif defined?(Mysql2)
          Mysql2::Error
        else
          StandardError
        end
      end

      def grant_statement
        <<-SQL
GRANT ALL PRIVILEGES ON #{configuration['database']}.*
  TO '#{configuration['username']}'@'localhost'
IDENTIFIED BY '#{configuration['password']}' WITH GRANT OPTION;
        SQL
      end

      def root_configuration_without_database
        configuration_without_database.merge(
          "username" => "root",
          "password" => root_password
        )
      end

      def root_password
        $stdout.print "Please provide the root password for your MySQL installation\n>"
        $stdin.gets.strip
      end

      def prepare_command_options
        args = {
          "host"      => "--host",
          "port"      => "--port",
          "socket"    => "--socket",
          "username"  => "--user",
          "password"  => "--password",
          "encoding"  => "--default-character-set",
          "sslca"     => "--ssl-ca",
          "sslcert"   => "--ssl-cert",
          "sslcapath" => "--ssl-capath",
          "sslcipher" => "--ssl-cipher",
          "sslkey"    => "--ssl-key"
        }.map { |opt, arg| "#{arg}=#{configuration[opt]}" if configuration[opt] }.compact

        args
      end

      def run_cmd(cmd, args, action)
        fail run_cmd_error(cmd, args, action) unless Kernel.system(cmd, *args)
      end

      def run_cmd_error(cmd, args, action)
        msg = "failed to execute: `#{cmd}`\n"
        msg << "Please check the output above for any errors and make sure that `#{cmd}` is installed in your PATH and has proper permissions.\n\n"
        msg
      end
    end
  end
end
