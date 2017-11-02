# frozen_string_literal: true
begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update
                your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"

  gem "benchmark-ips"
  gem "rails"
end

def allocate_count
  GC.disable
  before = ObjectSpace.count_objects
  yield
  after = ObjectSpace.count_objects
  after.each { |k,v| after[k] = v - before[k] }
  after[:T_HASH] -= 1 # probe effect - we created the before hash.
  GC.enable
  result = after.reject { |k,v| v == 0 }
  GC.start
  result
end

@hash = {}

def master_version
  "#{@hash["rel"]} nofollow".lstrip
end

def key_version
  if @hash.key?("rel")
    "#{@hash["rel"]} nofollow".lstrip
  else
    "nofollow"
  end
end

def present_version
  if @hash["rel"].present?
    "#{@hash["rel"]} nofollow"
  else
    "nofollow".freeze
  end
end

def nil_version
  if @hash["rel"].nil?
    "nofollow".freeze
  else
    "#{@hash["rel"]} nofollow"
  end
end

def blank_version
  if @hash["rel"].blank?
    "nofollow".freeze
  else
    "#{@hash["rel"]} nofollow"
  end
end

def test
  puts "master_version"
  puts allocate_count { 1000.times { master_version } }
  puts "key_version"
  puts allocate_count { 1000.times { key_version } }
  puts "present_version"
  puts allocate_count { 1000.times { present_version } }
  puts "nil_version"
  puts allocate_count { 1000.times { nil_version } }
  puts "blank_version"
  puts allocate_count { 1000.times { blank_version } }

  Benchmark.ips do |x|
    x.report("master_version")  { master_version }
    x.report("key_version")     { key_version }
    x.report("present_version") { present_version }
    x.report("nil_version")     { nil_version }
    x.report("blank_version")     { blank_version }
    x.compare!
  end
end

puts 'no rel key'

test

puts 'rel key with real stuff'

@hash['rel'] = 'hi'.freeze

test

puts 'rel key with nil'

@hash['rel'] = nil

test

puts 'rel key with ""'

@hash['rel'] = ""

test
