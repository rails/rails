#! /usr/bin/ruby
$:.unshift File.expand_path("../lib", File.dirname(__FILE__))

require 'i18n'
require 'i18n/core_ext/object/meta_class'
require 'benchmark'
require 'yaml'

# Load YAML example file
YAML_HASH = YAML.load_file(File.expand_path("example.yml", File.dirname(__FILE__)))

# Create benchmark backends
def create_backend(*modules)
  Class.new do
    modules.unshift(:Base)
    modules.each { |m| include I18n::Backend.const_get(m) }
  end
end

BACKENDS = []
BACKENDS << (SimpleBackend        = create_backend)
BACKENDS << (FastBackend          = create_backend(:Fast))
BACKENDS << (InterpolationBackend = create_backend(:InterpolationCompiler))
BACKENDS << (FastInterpolBackend  = create_backend(:Fast, :InterpolationCompiler))

# Hack Report to print ms
module Benchmark
  def self.ms(label = "", width=20, &blk) # :yield:
    print label.ljust(width)
    res = Benchmark::measure(&blk)
    print format("%10.6f ms\n", res.real * 1000)
    res
  end
end

# Run!
BACKENDS.each do |backend|
  I18n.backend = backend.new
  puts "===> #{backend.name}\n\n"

  Benchmark.ms "store" do
    I18n.backend.store_translations *(YAML_HASH.to_a.first)
    I18n.backend.translate :en, :first
  end

  Benchmark.ms "t (depth=3)" do
    I18n.backend.translate :en, :"activerecord.models.user"
  end

  Benchmark.ms "t (depth=5)" do
    I18n.backend.translate :en, :"activerecord.attributes.admins.user.login"
  end

  Benchmark.ms "t (depth=7)" do
    I18n.backend.translate :en, :"activerecord.errors.models.user.attributes.login.blank"
  end

  Benchmark.ms "t w/ default" do
    I18n.backend.translate :en, :"activerecord.models.another", :default => "Another"
  end

  Benchmark.ms "t w/ interpolation" do
    I18n.backend.translate :en, :"activerecord.errors.models.user.blank", :model => "User", :attribute => "name"
  end

  Benchmark.ms "t subtree" do
    I18n.backend.translate :en, :"activerecord.errors.messages"
  end

  puts
end