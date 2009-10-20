ORIG_ARGV = ARGV.dup

bundled = "#{File.dirname(__FILE__)}/../vendor/gems/environment"
if File.exist?("#{bundled}.rb")
  require bundled
else
  %w(activesupport activemodel activerecord actionpack actionmailer activeresource).each do |lib|
    $LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../#{lib}/lib"
  end
end

$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../builtin/rails_info"

require 'stringio'
require 'test/unit'
require 'fileutils'

require 'active_support'
require 'active_support/core_ext/logger'
require 'active_support/test_case'

require 'action_controller'
require 'rails'

Rails::Initializer.run do |config|
  config.root = File.dirname(__FILE__)
end
