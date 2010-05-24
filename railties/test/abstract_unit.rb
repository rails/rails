$:.unshift File.expand_path('../../../activesupport/lib', __FILE__)
$:.unshift File.expand_path('../../../activerecord/lib', __FILE__)
$:.unshift File.expand_path('../../../actionpack/lib', __FILE__)
$:.unshift File.expand_path('../../../actionmailer/lib', __FILE__)
$:.unshift File.expand_path('../../lib', __FILE__)
$:.unshift File.expand_path('../../builtin/rails_info', __FILE__)

require 'stringio'
require 'rubygems'
require 'test/unit'

require 'active_support'
require 'active_support/test_case'

if defined?(RAILS_ROOT)
  RAILS_ROOT.replace File.dirname(__FILE__)
else
  RAILS_ROOT = File.dirname(__FILE__)
end

def uses_gem(gem_name, test_name, version = '> 0')
  gem gem_name.to_s, version
  require gem_name.to_s
  yield
rescue LoadError
  $stderr.puts "Skipping #{test_name} tests. `gem install #{gem_name}` and try again."
end
