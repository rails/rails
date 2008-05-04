require 'optparse'
OptionParser.new do |opt|
  opt.banner = "Usage: dbconsole [environment]"
  opt.parse!(ARGV)
  abort opt.to_s unless (0..1).include?(ARGV.size)
end

env = ENV['RAILS_ENV'] = ARGV.first || ENV['RAILS_ENV'] || 'development'

def find_cmd(*commands)
  dirs_on_path = ENV['PATH'].split(File::PATH_SEPARATOR)
  commands += commands.map{|cmd| "#{cmd}.exe"} if RUBY_PLATFORM =~ /win32/
  commands.detect do |cmd|
    dirs_on_path.detect do |path|
      File.executable? File.join(path, cmd)
    end
  end || abort("couldn't find matching executable: #{commands.join(', ')}")
end


require 'yaml'
config = YAML::load(File.read(RAILS_ROOT + "/config/database.yml"))[env]

unless config
  abort "No database is configured for the environment '#{env}'"
end

case config["adapter"]
when "mysql"
  exec(find_cmd(*%w(mysql5 mysql)),
       *({ 'host'      => '--host',
           'port'      => '--port',
           'socket'    => '--socket',
           'username'  => '--user',
           'password'  => '--password',
           'encoding'  => '--default-character-set'
         }.map { |opt, arg| "#{arg}=#{config[opt]}" if config[opt] }.compact +
         [config['database']]))
when "postgresql"
  ENV['PGHOST']     = config["host"] if config["host"]
  ENV['PGPORT']     = config["port"].to_s if config["port"]
  ENV['PGPASSWORD'] = config["password"].to_s if config["password"]
  exec(find_cmd('psql'), '-U', config["username"], config["database"])
when "sqlite"
  exec(find_cmd('sqlite'), config["database"])
when "sqlite3"
  exec(find_cmd('sqlite3'), config["database"])
else abort "not supported for this database type"
end
