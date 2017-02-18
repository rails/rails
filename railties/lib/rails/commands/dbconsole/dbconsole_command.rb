require "rails/command/environment_argument"

module Rails
  class DBConsole
    def self.start(*args)
      new(*args).start
    end

    def initialize(options = {})
      @options = options
    end

    def start
      ENV["RAILS_ENV"] = @options[:environment] || environment

      case config["adapter"]
      when /^(jdbc)?mysql/
        args = {
          "host"      => "--host",
          "port"      => "--port",
          "socket"    => "--socket",
          "username"  => "--user",
          "encoding"  => "--default-character-set",
          "sslca"     => "--ssl-ca",
          "sslcert"   => "--ssl-cert",
          "sslcapath" => "--ssl-capath",
          "sslcipher" => "--ssl-cipher",
          "sslkey"    => "--ssl-key"
        }.map { |opt, arg| "#{arg}=#{config[opt]}" if config[opt] }.compact

        if config["password"] && @options["include_password"]
          args << "--password=#{config['password']}"
        elsif config["password"] && !config["password"].to_s.empty?
          args << "-p"
        end

        args << config["database"]

        find_cmd_and_exec(["mysql", "mysql5"], *args)

      when /^postgres|^postgis/
        ENV["PGUSER"]     = config["username"] if config["username"]
        ENV["PGHOST"]     = config["host"] if config["host"]
        ENV["PGPORT"]     = config["port"].to_s if config["port"]
        ENV["PGPASSWORD"] = config["password"].to_s if config["password"] && @options["include_password"]
        find_cmd_and_exec("psql", config["database"])

      when "sqlite3"
        args = []

        args << "-#{@options['mode']}" if @options["mode"]
        args << "-header" if @options["header"]
        args << File.expand_path(config["database"], Rails.respond_to?(:root) ? Rails.root : nil)

        find_cmd_and_exec("sqlite3", *args)

      when "oracle", "oracle_enhanced"
        logon = ""

        if config["username"]
          logon = config["username"]
          logon << "/#{config['password']}" if config["password"] && @options["include_password"]
          logon << "@#{config['database']}" if config["database"]
        end

        find_cmd_and_exec("sqlplus", logon)

      when "sqlserver"
        args = []

        args += ["-D", "#{config['database']}"] if config["database"]
        args += ["-U", "#{config['username']}"] if config["username"]
        args += ["-P", "#{config['password']}"] if config["password"]

        if config["host"]
          host_arg = "#{config['host']}"
          host_arg << ":#{config['port']}" if config["port"]
          args += ["-S", host_arg]
        end

        find_cmd_and_exec("sqsh", *args)

      else
        abort "Unknown command-line client for #{config['database']}."
      end
    end

    def config
      @config ||= begin
        if configurations[environment].blank?
          raise ActiveRecord::AdapterNotSpecified, "'#{environment}' database is not configured. Available configuration: #{configurations.inspect}"
        else
          configurations[environment]
        end
      end
    end

    def environment
      Rails.respond_to?(:env) ? Rails.env : Rails::Command.environment
    end

    private
      def configurations # :doc:
        require APP_PATH
        ActiveRecord::Base.configurations = Rails.application.config.database_configuration
        ActiveRecord::Base.configurations
      end

      def find_cmd_and_exec(commands, *args) # :doc:
        commands = Array(commands)

        dirs_on_path = ENV["PATH"].to_s.split(File::PATH_SEPARATOR)
        unless (ext = RbConfig::CONFIG["EXEEXT"]).empty?
          commands = commands.map { |cmd| "#{cmd}#{ext}" }
        end

        full_path_command = nil
        found = commands.detect do |cmd|
          dirs_on_path.detect do |path|
            full_path_command = File.join(path, cmd)
            File.file?(full_path_command) && File.executable?(full_path_command)
          end
        end

        if found
          exec full_path_command, *args
        else
          abort("Couldn't find database client: #{commands.join(', ')}. Check your $PATH and try again.")
        end
      end
  end

  module Command
    class DbconsoleCommand < Base # :nodoc:
      include EnvironmentArgument

      class_option :include_password, aliases: "-p", type: :boolean,
        desc: "Automatically provide the password from database.yml"

      class_option :mode, enum: %w( html list line column ), type: :string,
        desc: "Automatically put the sqlite3 database in the specified mode (html, list, line, column)."

      class_option :header, type: :string

      class_option :environment, aliases: "-e", type: :string,
        desc: "Specifies the environment to run this console under (test/development/production)."

      def perform
        extract_environment_option_from_argument

        Rails::DBConsole.start(options)
      end
    end
  end
end
