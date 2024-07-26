INCLUDES = [ 
  "app/models", 
  "app/controllers", 
  "app/helpers", 
  "config", 
  "lib", 
  "vendor",
  "vendor/railties", 
  "vendor/railties/lib", 
  "vendor/activerecord/lib", 
  "vendor/actionpack/lib",
]

INCLUDES.each { |dir| $:.unshift "#{File.dirname(__FILE__)}/../../../#{dir}" }
