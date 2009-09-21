begin
  require 'i18n'
rescue LoadError
  $:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'i18n-0.1.3', 'lib'))
  retry
end
