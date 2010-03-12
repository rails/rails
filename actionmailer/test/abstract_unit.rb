require File.expand_path('../../../load_paths', __FILE__)

lib = File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'test/unit'
require 'action_mailer'
require 'action_mailer/test_case'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Bogus template processors
ActionView::Template.register_template_handler :haml, lambda { |template| "Look its HAML!".inspect }
ActionView::Template.register_template_handler :bak, lambda { |template| "Lame backup".inspect }

FIXTURE_LOAD_PATH = File.expand_path('fixtures', File.dirname(__FILE__))
ActionMailer::Base.view_paths = FIXTURE_LOAD_PATH

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

def set_delivery_method(method)
  @old_delivery_method = ActionMailer::Base.delivery_method
  ActionMailer::Base.delivery_method = method
end

def restore_delivery_method
  ActionMailer::Base.delivery_method = @old_delivery_method
end