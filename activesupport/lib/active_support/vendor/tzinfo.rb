begin
  require 'tzinfo'
rescue LoadError
  $:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'tzinfo-0.3.13', 'lib'))
  retry
end
