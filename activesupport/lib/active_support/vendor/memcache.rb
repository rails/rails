begin
  require 'memcache'
rescue LoadError
  $:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'memcache-client-1.7.5', 'lib'))
  retry
end
