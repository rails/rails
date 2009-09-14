begin
  require 'builder'
rescue LoadError
  $:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'builder-2.1.2', 'lib'))
  retry
end
