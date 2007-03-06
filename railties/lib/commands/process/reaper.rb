require 'optparse'
require 'net/http'
require 'uri'

if RUBY_PLATFORM =~ /(:?mswin|mingw)/ then abort("Reaper is only for Unix") end

class Killer
  class << self
    # Searches for all processes matching the given keywords, and then invokes
    # a specific action on each of them. This is useful for (e.g.) reloading a
    # set of processes:
    #
    #   Killer.process(:reload, "/tmp/pids", "dispatcher.*.pid")
    def process(action, pid_path, pattern, keyword)
      new(pid_path, pattern, keyword).process(action)
    end

    # Forces the (rails) application to reload by sending a +HUP+ signal to the
    # process.
    def reload(pid)
      `kill -s HUP #{pid}`
    end

    # Force the (rails) application to restart by sending a +USR2+ signal to the
    # process.
    def restart(pid)
      `kill -s USR2 #{pid}`
    end

    # Forces the (rails) application to gracefully terminate by sending a
    # +TERM+ signal to the process.
    def graceful(pid)
      `kill -s TERM #{pid}`
    end

    # Forces the (rails) application to terminate immediately by sending a -9
    # signal to the process.
    def kill(pid)
      `kill -9 #{pid}`
    end

    # Send a +USR1+ signal to the process.
    def usr1(pid)
      `kill -s USR1 #{pid}`
    end
  end

  def initialize(pid_path, pattern, keyword=nil)
    @pid_path, @pattern, @keyword = pid_path, pattern, keyword
  end

  def process(action)
    pids = find_processes

    if pids.empty?
      warn "Couldn't find any pid file in '#{@pid_path}' matching '#{@pattern}'"
      warn "(also looked for processes matching #{@keyword.inspect})" if @keyword
    else
      pids.each do |pid|
        puts "#{action.capitalize}ing #{pid}"
        self.class.send(action, pid)
      end
      
      delete_pid_files if terminating?(action)
    end      
  end
  
  private
    def terminating?(action)
      [ "kill", "graceful" ].include?(action)
    end
  
    def find_processes
      files = pid_files
      if files.empty?
        find_processes_via_grep
      else
        files.collect { |pid_file| File.read(pid_file).to_i }
      end
    end

    def find_processes_via_grep
      lines = `ps axww -o 'pid command' | grep #{@keyword}`.split(/\n/).
        reject { |line| line =~ /inq|ps axww|grep|spawn-fcgi|spawner|reaper/ }
      lines.map { |line| line[/^\s*(\d+)/, 1].to_i }
    end
    
    def delete_pid_files
      pid_files.each { |pid_file| File.delete(pid_file) }
    end
    
    def pid_files
      Dir.glob(@pid_path + "/" + @pattern)
    end
end


OPTIONS = {
  :action     => "restart",
  :pid_path   => File.expand_path(RAILS_ROOT + '/tmp/pids'),
  :pattern    => "dispatch.[0-9]*.pid",
  :dispatcher => File.expand_path("#{RAILS_ROOT}/public/dispatch.fcgi")
}

ARGV.options do |opts|
  opts.banner = "Usage: reaper [options]"

  opts.separator ""

  opts.on <<-EOF
  Description:
    The reaper is used to restart, reload, gracefully exit, and forcefully exit processes
    running a Rails Dispatcher (or any other process responding to the same signals). This
    is commonly done when a new version of the application is available, so the existing
    processes can be updated to use the latest code.

    It uses pid files to work on the processes and by default assume them to be located
    in RAILS_ROOT/tmp/pids. 

    The reaper actions are:

    * restart : Restarts the application by reloading both application and framework code
    * reload  : Only reloads the application, but not the framework (like the development environment)
    * graceful: Marks all of the processes for exit after the next request
    * kill    : Forcefully exists all processes regardless of whether they're currently serving a request

    Restart is the most common and default action.

  Examples:
    reaper                  # restarts the default dispatchers
    reaper -a reload        # reload the default dispatchers
    reaper -a kill -r *.pid # kill all processes that keep pids in tmp/pids
  EOF

  opts.on("  Options:")

  opts.on("-a", "--action=name", "reload|graceful|kill (default: #{OPTIONS[:action]})", String)  { |v| OPTIONS[:action] = v }
  opts.on("-p", "--pidpath=path", "default: #{OPTIONS[:pid_path]}", String)                      { |v| OPTIONS[:pid_path] = v }
  opts.on("-r", "--pattern=pattern", "default: #{OPTIONS[:pattern]}", String)                    { |v| OPTIONS[:pattern] = v }
  opts.on("-d", "--dispatcher=path", "DEPRECATED. default: #{OPTIONS[:dispatcher]}", String)     { |v| OPTIONS[:dispatcher] = v }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

Killer.process(OPTIONS[:action], OPTIONS[:pid_path], OPTIONS[:pattern], OPTIONS[:dispatcher])
