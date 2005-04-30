# No GC nonsense.
GC.disable

# Try to load the ruby-prof extension; fail back to the pure-Ruby
# profiler included in the standard library.
begin
  require 'prof'
  Prof.clock_mode = Prof::CPU
  puts 'Using the fast ruby-prof extension'
  require 'unprof'
rescue LoadError
  puts 'Using the slow pure-Ruby profiler'
  require 'profile'
end
