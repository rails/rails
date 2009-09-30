if ARGV.empty?
  $stderr.puts "Usage: ./script/performance/profiler 'Person.expensive_method(10)' [times] [flat|graph|graph_html]"
  exit(1)
end

# Keep the expensive require out of the profile.
$stderr.puts 'Loading Rails...'
require RAILS_ROOT + '/config/environment'

# Define a method to profile.
if ARGV[1] and ARGV[1].to_i > 1
  eval "def profile_me() #{ARGV[1]}.times { #{ARGV[0]} } end"
else
  eval "def profile_me() #{ARGV[0]} end"
end

# Use the ruby-prof extension if available.  Fall back to stdlib profiler.
begin
  begin
    require "ruby-prof"
    $stderr.puts 'Using the ruby-prof extension.'
    RubyProf.measure_mode = RubyProf::WALL_TIME
    RubyProf.start
    profile_me
    results = RubyProf.stop
    if ARGV[2]
      printer_class = RubyProf.const_get((ARGV[2] + "_printer").classify)
    else
      printer_class = RubyProf::FlatPrinter
    end
    printer = printer_class.new(results)
    printer.print($stderr)
  rescue LoadError
    require "prof"
    $stderr.puts 'Using the old ruby-prof extension.'
    Prof.clock_mode = Prof::GETTIMEOFDAY
    Prof.start
    profile_me
    results = Prof.stop
    require 'rubyprof_ext'
    Prof.print_profile(results, $stderr)
  end
rescue LoadError
  require 'profiler'
  $stderr.puts 'Using the standard Ruby profiler.'
  Profiler__.start_profile
  profile_me
  Profiler__.stop_profile
  Profiler__.print_profile($stderr)
end
