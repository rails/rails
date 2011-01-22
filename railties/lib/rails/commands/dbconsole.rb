require 'erb'

begin
  require 'psych'
rescue LoadError
end

require 'yaml'
require 'optparse'
require 'rbconfig'

module Rails
  class DBConsole
    def self.start(app)
      new(app).start
    end

    def initialize(app)
      @app = app
    end

    def start
      include_password = false
      options = {}
      OptionParser.new do |opt|
        opt.banner = "Usage: dbconsole [options] [environment]"
        opt.on("-p", "--include-password", "Automatically provide the password from database.yml") do |v|
          include_password = true
        end

        opt.on("--mode [MODE]", ['html', 'list', 'line', 'column'],
          "Automatically put the sqlite3 database in the specified mode (html, list, line, column).") do |mode|
            options['mode'] = mode
        end

        opt.on("-h", "--header") do |h|
          options['header'] = h
        end

        opt.parse!(ARGV)
        abort opt.to_s unless (0..1).include?(ARGV.size)
      end

      unless config = YAML::load(ERB.new(IO.read("#{@app.root}/config/database.yml")).result)[Rails.env]
        abort "No database is configured for the environment '#{Rails.env}'"
      end


      def find_cmd(*commands)
        dirs_on_path = ENV['PATH'].to_s.split(File::PATH_SEPARATOR)
        commands += commands.map{|cmd| "#{cmd}.exe"} if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/

        full_path_command = nil
        found = commands.detect do |cmd|
          dir = dirs_on_path.detect do |path|
            full_path_command = File.join(path, cmd)
            File.executable? full_path_command
          end
        end
        found ? full_path_command : abort("Couldn't find database client: #{commands.join(', ')}. Check your $PATH and try again.")
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

        exec(find_cmd('mysql', 'mysql5'), *args)

      when "postgresql"
        ENV['PGUSER']     = config["username"] if config["username"]
        ENV['PGHOST']     = config["host"] if config["host"]
        ENV['PGPORT']     = config["port"].to_s if config["port"]
        ENV['PGPASSWORD'] = config["password"].to_s if config["password"] && include_password
        exec(find_cmd('psql'), config["database"])

      when "sqlite"
        exec(find_cmd('sqlite'), config["database"])

      when "sqlite3"
        args = []

        args << "-#{options['mode']}" if options['mode']
        args << "-header" if options['header']
        args << config['database']

        exec(find_cmd('sqlite3'), *args)

      when "oracle", "oracle_enhanced"
        logon = ""

        if config['username']
          logon = config['username']
          logon << "/#{config['password']}" if config['password'] && include_password
          logon << "@#{config['database']}" if config['database']
        end

        exec(find_cmd('sqlplus'), logon)

      else
        abort "Unknown command-line client for #{config['database']}. Submit a Rails patch to add support!"
      end
    end
  end
end

# Has to set the RAILS_ENV before config/application is required
if ARGV.first && !ARGV.first.index("-") && env = ARGV.first
  ENV['RAILS_ENV'] = %w(production development test).find { |e| e.index(env) } || env
end
