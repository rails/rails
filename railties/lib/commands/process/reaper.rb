require 'optparse'
require 'net/http'
require 'uri'

if RUBY_PLATFORM =~ /mswin32/ then abort("Reaper is only for Unix") end

# Instances of this class represent a single running process. Processes may
# be queried by "keyword" to find those that meet a specific set of criteria.
class ProgramProcess
  class << self
    
    # Searches for all processes matching the given keywords, and then invokes
    # a specific action on each of them. This is useful for (e.g.) reloading a
    # set of processes:
    #
    #   ProgramProcess.process_keywords(:reload, "basecamp")
    def process_keywords(action, *keywords)
      processes = keywords.collect { |keyword| find_by_keyword(keyword) }.flatten

      if processes.empty?
        puts "Couldn't find any process matching: #{keywords.join(" or ")}"
      else
        processes.each do |process|
          puts "#{action.capitalize}ing #{process}"
          process.send(action)
        end
      end      
    end

    # Searches for all processes matching the given keyword:
    #
    #   ProgramProcess.find_by_keyword("basecamp")
    def find_by_keyword(keyword)
      process_lines_with_keyword(keyword).split("\n").collect { |line|
        next if line =~ /inq|ps axww|grep|spawn-fcgi|spawner|reaper/
        pid, *command = line.split
        new(pid, command.join(" "))
      }.compact
    end

    private
      def process_lines_with_keyword(keyword)
        `ps axww -o 'pid command' | grep #{keyword}`
      end
  end

  # Create a new ProgramProcess instance that represents the process with the
  # given pid, running the given command.
  def initialize(pid, command)
    @pid, @command = pid, command
  end

  # Forces the (rails) application to reload by sending a +HUP+ signal to the
  # process.
  def reload
    `kill -s HUP #{@pid}`
  end

  # Forces the (rails) application to gracefully terminate by sending a
  # +TERM+ signal to the process.
  def graceful
    `kill -s TERM #{@pid}`
  end

  # Forces the (rails) application to terminate immediately by sending a -9
  # signal to the process.
  def kill
    `kill -9 #{@pid}`
  end

  # Send a +USR1+ signal to the process.
  def usr1
    `kill -s USR1 #{@pid}`
  end

  # Force the (rails) application to restart by sending a +USR2+ signal to the
  # process.
  def restart
    `kill -s USR2 #{@pid}`
  end

  def to_s #:nodoc:
    "[#{@pid}] #{@command}"
  end
end

OPTIONS = {
  :action      => "restart",
  :dispatcher  => File.expand_path(RAILS_ROOT + '/public/dispatch.fcgi')
}

ARGV.options do |opts|
  opts.banner = "Usage: reaper [options]"

  opts.separator ""

  opts.on <<-EOF
  Description:
    The reaper is used to restart, reload, gracefully exit, and forcefully exit FCGI processes
    running a Rails Dispatcher. This is commonly done when a new version of the application
    is available, so the existing processes can be updated to use the latest code.

    The reaper actions are:

    * restart : Restarts the application by reloading both application and framework code
    * reload  : Only reloads the application, but not the framework (like the development environment)
    * graceful: Marks all of the processes for exit after the next request
    * kill    : Forcefully exists all processes regardless of whether they're currently serving a request

    Restart is the most common and default action.

  Examples:
    reaper # restarts the default dispatcher
    reaper -a reload
    reaper -a exit -d /my/special/dispatcher.fcgi
  EOF

  opts.on("  Options:")

  opts.on("-a", "--action=name", "reload|graceful|kill (default: #{OPTIONS[:action]})", String)  { |v| OPTIONS[:action] = v }
  opts.on("-d", "--dispatcher=path", "default: #{OPTIONS[:dispatcher]}", String)                 { |v| OPTIONS[:dispatcher] = v }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

ProgramProcess.process_keywords(OPTIONS[:action], OPTIONS[:dispatcher])