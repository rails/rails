require 'erb'
require 'yaml'
require 'optparse'
require 'rbconfig'

module Rails
  class DBConsole
    attr_reader :arguments

    def self.start(app)
      new(app).start
    end

    def initialize(app, arguments = ARGV)
      @app = app
      @arguments = arguments
    end

    def start
      include_password = false
      options = {}
      OptionParser.new do |opt|
        opt.banner = "Usage: dbconsole [environment] [options]"
        opt.on("-p", "--include-password", "Automatically provide the password from database.yml") do |v|
          include_password = true
        end

        opt.on("--mode [MODE]", ['html', 'list', 'line', 'column'],
          "Automatically put the sqlite3 database in the specified mode (html, list, line, column).") do |mode|
            options['mode'] = mode
        end

        opt.on("--header") do |h|
          options['header'] = h
        end

        opt.parse!(arguments)
        abort opt.to_s unless (0..1).include?(arguments.size)
      end

      unless config = @app.config.database_configuration[Rails.env]
        abort "No database is configured for the environment '#{Rails.env}'"
      end


      case config["adapter"]
      when /^mysql/
        args = {
          'host'      => '--host',
          'port'      => '--port',
          'socket'    => '--socket',
          'username'  => '--user',
          'encoding'  => '--default-character-set'
        }.map { |opt, arg| "#{arg}=#{config[opt]}" if config[opt] }.compact

        if config['password'] && include_password
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
        ENV['PGPASSWORD'] = config["password"].to_s if config["password"] && include_password
        find_cmd_and_exec('psql', config["database"])

      when "sqlite"
        find_cmd_and_exec('sqlite', config["database"])

      when "sqlite3"
        args = []

        args << "-#{options['mode']}" if options['mode']
        args << "-header" if options['header']
        args << config['database']

        find_cmd_and_exec('sqlite3', *args)

      when "oracle", "oracle_enhanced"
        logon = ""

        if config['username']
          logon = config['username']
          logon << "/#{config['password']}" if config['password'] && include_password
          logon << "@#{config['database']}" if config['database']
        end

        find_cmd_and_exec('sqlplus', logon)

      else
        abort "Unknown command-line client for #{config['database']}. Submit a Rails patch to add support!"
      end
    end

    protected

    def find_cmd_and_exec(commands, *args)
      commands = Array(commands)

      dirs_on_path = ENV['PATH'].to_s.split(File::PATH_SEPARATOR)
      commands += commands.map{|cmd| "#{cmd}.exe"} if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/

      full_path_command = nil
      found = commands.detect do |cmd|
        dir = dirs_on_path.detect do |path|
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

# Has to set the RAILS_ENV before config/application is required
if ARGV.first && !ARGV.first.index("-") && env = ARGV.first
  ENV['RAILS_ENV'] = %w(production development test).detect {|e| e =~ /^#{env}/} || env
end
