require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'action_mailer'

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
end

class Net::SMTP
  def self.start(*args)
    yield MockSMTP.new
  end
end
