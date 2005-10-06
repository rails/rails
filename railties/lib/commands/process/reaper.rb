require 'optparse'
require 'net/http'
require 'uri'

if RUBY_PLATFORM =~ /mswin32/ then abort("Reaper is only for Unix") end

class ProgramProcess
  class << self
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

    def find_by_keyword(keyword)
      process_lines_with_keyword(keyword).split("\n").collect { |line|
        next if line.include?("inq") || line.include?("ps -ax") || line.include?("grep")
        pid, *command = line.split
        new(pid, command.join(" "))
      }.compact
    end

    private
      def process_lines_with_keyword(keyword)
        `ps -ax -o 'pid command' | grep #{keyword}`
      end
  end

  def initialize(pid, command)
    @pid, @command = pid, command
  end

  def find
  end

  def reload
    `kill -s HUP #{@pid}`
  end

  def graceful
    `kill -s TERM #{@pid}`
  end

  def kill
    `kill -9 #{@pid}`
  end

  def usr1
    `kill -s USR1 #{@pid}`
  end

  def restart
    `kill -s USR2 #{@pid}`
  end

  def to_s
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

    A nudge is simply a request to a URL where the dispatcher is serving. You should perform one nudge per
    FCGI process you have running if they're setup in a round-robin. Be sure to do one nudge per FCGI process
    across all your servers. So three servers with 10 processes each should nudge 30 times to be sure all processes
    are restarted.

  Examples:
    reaper -a reload
  EOF

  opts.on("  Options:")

  opts.on("-a", "--action=name", "reload|graceful|kill (default: #{OPTIONS[:action]})", String)  { |OPTIONS[:action]| }
  opts.on("-d", "--dispatcher=path", "default: #{OPTIONS[:dispatcher]}", String)                 { |OPTIONS[:dispatcher]| }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

ProgramProcess.process_keywords(OPTIONS[:action], OPTIONS[:dispatcher])