#!/usr/bin/env ruby
Dir.chdir(File.expand_path("..", __FILE__))
$: << File.expand_path("../lib", __FILE__)
require "active_support"

ActiveSupport::TimeZone.all

def flatten_constants(mod, ary = [])
  ary << mod
  mod.constants.each do |const|
    flatten_constants(mod.const_get(const), ary)
  end
  ary
end

defns = flatten_constants(TZInfo::Definitions).select { |mod|
  defined?(mod.get)
}.map { |tz|
  tz.get
}

file = "lib/active_support/vendor/tzinfo-0.3.12/tzinfo/definitions.dump"
data = Marshal.dump(defns)
Marshal.load(data)
File.open(file, "wb") do |f|
  require "pry"
  pry binding
  f.write(data)
end
puts "Wrote #{data.size} bytes to #{file}"
