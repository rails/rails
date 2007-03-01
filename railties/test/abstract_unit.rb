$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"
$:.unshift File.dirname(__FILE__) + "/../../actionpack/lib"
$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../builtin/rails_info"

require 'test/unit'
require 'active_support'

if defined?(RAILS_ROOT)
  RAILS_ROOT.replace File.dirname(__FILE__)
else
  RAILS_ROOT = File.dirname(__FILE__)
end

class Test::Unit::TestCase
  # Add stuff here if you need it
end
