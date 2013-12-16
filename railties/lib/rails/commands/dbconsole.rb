require 'erb'
require 'yaml'
require 'optparse'
require 'rbconfig'

module Rails
  class DBConsole
    attr_reader :arguments

    def self.start
      new.start
    end

    def initialize(arguments = ARGV)
      @arguments = arguments
    end

    def start
      options = parse_arguments(arguments)
      ENV['RAILS_ENV'] = options[:environment] || environment

      case config["adapter"]
      when /^mysql/
        args = {
          'host'      => '--host',
          'port'      => '--port',
          'socket'    => '--socket',
          'username'  => '--user',
          'encoding'  => '--default-character-set',
          'sslca'     => '--ssl-ca',
          'sslcert'   => '--ssl-cert',
          'sslcapath' => '--ssl-capath',
          'sslcipher' => '--ssh-cipher',
          'sslkey'    => '--ssl-key'
        }.map { |opt, arg| "#{arg}=#{config[opt]}" if config[opt] }.compact

        if config['password'] && options['include_password']
          args << "--password=#{config['password']}"
        elsif config['password'] && !config['password'].to_s.empty?
          args << "-p"
        end

        args << config['database']

        find_cmd_and_exec(['mysql', 'mysql5'], *args)

      when "postgresql", "postgres"
        ENV['PGUSER']     = config["username"] if config["username"]
        ENV['PGHOST']     = config["host"] if config["host"]
        ENV['PGPORT']     = config["port"].to_s if config["port"]
        ENV['PGPASSWORD'] = config["password"].to_s if config["password"] && options['include_password']
        find_cmd_and_exec('psql', config["database"])

      when "sqlite"
        find_cmd_and_exec('sqlite', config["database"])

      when "sqlite3"
        args = []

        args << "-#{options['mode']}" if options['mode']
        args << "-header" if options['header']
        args << File.expand_path(config['database'], Rails.respond_to?(:root) ? Rails.root : nil)

        find_cmd_and_exec('sqlite3', *args)

      when "oracle", "oracle_enhanced"
        logon = ""

        if config['username']
          logon = config['username']
          logon << "/#{config['password']}" if config['password'] && options['include_password']
          logon << "@#{config['database']}" if config['database']
        end

        find_cmd_and_exec('sqlplus', logon)

      else
        abort "Unknown command-line client for #{config['database']}. Submit a Rails patch to add support!"
      end
    end

    def config
      @config ||= begin
        require APP_PATH
        ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new(
          ENV['DATABASE_URL'],
          (Rails.application.config.database_configuration || {})
        ).spec.config.stringify_keys
      end
    end

    def environment
      if Rails.respond_to?(:env)
        Rails.env
      else
        ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
      end
    end

    protected

    def parse_arguments(arguments)
      options = {}

      OptionParser.new do |opt|
        opt.banner = "Usage: rails dbconsole [environment] [options]"
        opt.on("-p", "--include-password", "Automatically provide the password from database.yml") do |v|
          options['include_password'] = true
        end

        opt.on("--mode [MODE]", ['html', 'list', 'line', 'column'],
          "Automatically put the sqlite3 database in the specified mode (html, list, line, column).") do |mode|
            options['mode'] = mode
        end

        opt.on("--header") do |h|
          options['header'] = h
        end

        opt.on("-h", "--help", "Show this help message.") do
          puts opt
          exit
        end

        opt.on("-e", "--environment=name", String,
          "Specifies the environment to run this console under (test/development/production).",
          "Default: development"
        ) { |v| options[:environment] = v.strip }

        opt.parse!(arguments)
        abort opt.to_s unless (0..1).include?(arguments.size)
      end

      if arguments.first && arguments.first[0] != '-'
        env = arguments.first
        if available_environments.include? env
          options[:environment] = env
        else
          options[:environment] = %w(production development test).detect {|e| e =~ /^#{env}/} || env
        end
      end

      options
    end

    def available_environments
      Dir['config/environments/*.rb'].map { |fname| File.basename(fname, '.*') }
    end

    def find_cmd_and_exec(commands, *args)
      commands = Array(commands)

      dirs_on_path = ENV['PATH'].to_s.split(File::PATH_SEPARATOR)
      commands += commands.map{|cmd| "#{cmd}.exe"} if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/

      full_path_command = nil
      found = commands.detect do |cmd|
        dirs_on_path.detect do |path|
          full_path_command = File.join(path, cmd)
          File.executable? full_path_command
        end
      end

      if found
        exec full_path_command, *args
      else
        abort("Couldn't find database client: #{commands.join(', ')}. Check your $PATH and try again.")
      end
    end
  end
end
