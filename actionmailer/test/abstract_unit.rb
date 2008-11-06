require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
$:.unshift "#{File.dirname(__FILE__)}/../../activesupport/lib"
$:.unshift "#{File.dirname(__FILE__)}/../../actionpack/lib"
require 'action_mailer'
require 'action_mailer/test_case'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

$:.unshift "#{File.dirname(__FILE__)}/fixtures/helpers"
ActionMailer::Base.template_root = "#{File.dirname(__FILE__)}/fixtures"

class MockSMTP
  def self.deliveries
    @@deliveries
  end

  def initialize
    @@deliveries = []
  end

  def sendmail(mail, from, to)
    @@deliveries << [mail, from, to]
  end

  def start(*args)
    yield self
  end
end

class Net::SMTP
  def self.new(*args)
    MockSMTP.new
  end
end

def uses_gem(gem_name, test_name, version = '> 0')
  require 'rubygems'
  gem gem_name.to_s, version
  require gem_name.to_s
  yield
rescue LoadError
  $stderr.puts "Skipping #{test_name} tests. `gem install #{gem_name}` and try again."
end

# Wrap tests that use Mocha and skip if unavailable.
unless defined? uses_mocha
  def uses_mocha(test_name, &block)
    uses_gem('mocha', test_name, '>= 0.5.5', &block)
  end
end

def set_delivery_method(delivery_method)
  @old_delivery_method = ActionMailer::Base.delivery_method
  ActionMailer::Base.delivery_method = delivery_method
end

def restore_delivery_method
  ActionMailer::Base.delivery_method = @old_delivery_method
end
