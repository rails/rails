#!/usr/bin/env ruby
# Example:
#   ruby -Iactivesupport/lib tools/profile_requires.rb active_support
#   ruby -Iactionpack/lib tools/profile_requires.rb action_controller
abort 'Use REE so you can profile memory and object allocation' unless GC.respond_to?(:enable_stats)

GC.enable_stats
require 'rubygems'
Gem.source_index
require 'benchmark'

module TrackHeapGrowth
  class << self
    attr_accessor :indent
    attr_accessor :stats
  end
  self.indent = 0
  self.stats = []

  def track_growth(file)
    TrackHeapGrowth.indent += 1
    heap_before, objects_before = GC.allocated_size, ObjectSpace.allocated_objects
    result = nil
    elapsed = Benchmark.realtime { result = yield }
    heap_after, objects_after = GC.allocated_size, ObjectSpace.allocated_objects
    TrackHeapGrowth.indent -= 1
    TrackHeapGrowth.stats << [file, TrackHeapGrowth.indent, elapsed, heap_after - heap_before, objects_after - objects_before] if result
    result
  end

  def require(file, *args)
    track_growth(file) { super }
  end

  def load(file, *args)
    track_growth(file) { super }
  end
end

Object.instance_eval { include TrackHeapGrowth }

GC.start
before = GC.allocated_size
before_rss = `ps -o rss= -p #{Process.pid}`.to_i
before_live_objects = ObjectSpace.live_objects

path = ARGV.shift

if mode = ARGV.shift
  require 'ruby-prof'
  RubyProf.measure_mode = RubyProf.const_get(mode.upcase)
  RubyProf.start
end

ENV['NO_RELOAD'] ||= '1'
ENV['RAILS_ENV'] ||= 'development'
elapsed = Benchmark.realtime { require path }
results = RubyProf.stop if mode

GC.start
after_live_objects = ObjectSpace.live_objects
after_rss = `ps -o rss= -p #{Process.pid}`.to_i
after = GC.allocated_size
usage = (after - before) / 1024.0

if mode
  File.open("profile_startup.#{mode}.tree", 'w') do |out|
    RubyProf::CallTreePrinter.new(results).print(out)
  end
end

TrackHeapGrowth.stats.reverse_each do |file, indent, sec, bytes, objects|
  puts "%10.2f KB %10d obj %8.1f ms  %s%s" % [bytes / 1024.0, objects, sec * 1000, ' ' * indent, file]
end
puts "%10.2f KB %10d obj %8.1f ms  %d KB RSS" % [usage, after_live_objects - before_live_objects, elapsed * 1000, after_rss - before_rss]
