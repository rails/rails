#! /usr/bin/ruby
$:.unshift File.expand_path('../../lib', __FILE__)

require 'i18n'
require 'benchmark'
require 'yaml'

DATA_STORES = ARGV.delete("-ds")
N = (ARGV.shift || 1000).to_i
YAML_HASH = YAML.load_file(File.expand_path("example.yml", File.dirname(__FILE__)))

module Backends
  Simple = I18n::Backend::Simple.new

  Interpolation = Class.new(I18n::Backend::Simple) do
    include I18n::Backend::InterpolationCompiler
  end.new

  if DATA_STORES
    require 'rubygems'
    require File.expand_path('../../test/test_setup_requirements', __FILE__)

    setup_active_record
    ActiveRecord = I18n::Backend::ActiveRecord.new if defined?(::ActiveRecord)

    setup_rufus_tokyo
    TokyoCabinet = I18n::Backend::KeyValue.new(Rufus::Tokyo::Cabinet.new("*"), true) if defined?(::Rufus::Tokyo)
  end
end

ORDER = %w(Simple Interpolation ActiveRecord TokyoCabinet)
ORDER.map!(&:to_sym) if RUBY_VERSION > '1.9'

module Benchmark
  WIDTH = 20

  def self.rt(label = "", n=N, &blk)
    print label.ljust(WIDTH)
    time, objects = measure_objects(n, &blk)
    time = time.respond_to?(:real) ? time.real : time
    print format("%8.2f ms  %8d objects\n", time * 1000, objects)
  rescue Exception => e
    print "FAILED: #{e.message}"
  end

  if ObjectSpace.respond_to?(:allocated_objects)
    def self.measure_objects(n, &blk)
      obj = ObjectSpace.allocated_objects
      t = Benchmark.realtime { n.times(&blk) }
      [t, ObjectSpace.allocated_objects - obj]
    end
  else
    def self.measure_objects(n, &blk)
      [Benchmark.measure { n.times(&blk) }, 0]
    end
  end
end

benchmarker = lambda do |backend_name|
  I18n.backend = Backends.const_get(backend_name)
  puts "=> #{backend_name}\n\n"

  Benchmark.rt "store", 1 do
    I18n.backend.store_translations *(YAML_HASH.to_a.first)
  end

  I18n.backend.translate :en, :first

  Benchmark.rt "available_locales" do
    I18n.backend.available_locales
  end

  Benchmark.rt "t (depth=3)" do
    I18n.backend.translate :en, :"activerecord.models.user"
  end

  Benchmark.rt "t (depth=5)" do
    I18n.backend.translate :en, :"activerecord.attributes.admins.user.login"
  end

  Benchmark.rt "t (depth=7)" do
    I18n.backend.translate :en, :"activerecord.errors.models.user.attributes.login.blank"
  end

  Benchmark.rt "t w/ default" do
    I18n.backend.translate :en, :"activerecord.models.another", :default => "Another"
  end

  Benchmark.rt "t w/ interpolation" do
    I18n.backend.translate :en, :"activerecord.errors.models.user.blank", :model => "User", :attribute => "name"
  end

  Benchmark.rt "t w/ link" do
    I18n.backend.translate :en, :"activemodel.errors.messages.blank"
  end

  Benchmark.rt "t subtree" do
    I18n.backend.translate :en, :"activerecord.errors.messages"
  end

  puts
end

# Run!
puts
puts "Running benchmarks with N = #{N}\n\n"
(ORDER & Backends.constants).each(&benchmarker)

Backends.constants.each do |backend_name|
 backend = Backends.const_get(backend_name)
 backend.reload!
 backend.extend I18n::Backend::Memoize
end

puts "Running memoized benchmarks with N = #{N}\n\n"
(ORDER & Backends.constants).each(&benchmarker)