require 'optparse'

if RUBY_PLATFORM =~ /(:?mswin|mingw)/ then abort("Inspector is only for Unix") end

OPTIONS = {
  :pid_path => File.expand_path(RAILS_ROOT + '/tmp/pids'),
  :pattern  => "dispatch.*.pid",
  :ps       => "ps -o pid,state,user,start,time,pcpu,vsz,majflt,command -p %s"
}

class Inspector
  def self.inspect(pid_path, pattern)
    new(pid_path, pattern).inspect
  end

  def initialize(pid_path, pattern)
    @pid_path, @pattern = pid_path, pattern
  end

  def inspect
    header = `#{OPTIONS[:ps] % 1}`.split("\n")[0] + "\n"
    lines  = pids.collect { |pid| `#{OPTIONS[:ps] % pid}`.split("\n")[1] }
    
    puts(header + lines.join("\n"))
  end

  private
    def pids
      pid_files.collect do |pid_file|
        File.read(pid_file).to_i
      end
    end

    def pid_files
      Dir.glob(@pid_path + "/" + @pattern)
    end
end


ARGV.options do |opts|
  opts.banner = "Usage: inspector [options]"

  opts.separator ""

  opts.on <<-EOF
  Description:
    Displays system information about Rails dispatchers (or other processes that use pid files) through
    the ps command.

  Examples:
    inspector                                             # default ps on all tmp/pids/dispatch.*.pid files
    inspector -s 'ps -o user,start,majflt,pcpu,vsz -p %s' # custom ps, %s is where the pid is interleaved
  EOF

  opts.on("  Options:")

  opts.on("-s", "--ps=command", "default: #{OPTIONS[:ps]}", String)           { |v| OPTIONS[:ps] = v }
  opts.on("-p", "--pidpath=path", "default: #{OPTIONS[:pid_path]}", String)   { |v| OPTIONS[:pid_path] = v }
  opts.on("-r", "--pattern=pattern", "default: #{OPTIONS[:pattern]}", String) { |v| OPTIONS[:pattern] = v }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

Inspector.inspect(OPTIONS[:pid_path], OPTIONS[:pattern])
