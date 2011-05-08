# Pathname has a warning, so require it first while silencing
# warnings to shut it up.
#
# Also, in 1.9, Bundler creates warnings due to overriding
# Rubygems methods
begin
  old, $VERBOSE = $VERBOSE, nil
  require 'pathname'
  require File.expand_path('../../../load_paths', __FILE__)
ensure
  $VERBOSE = old
end

require 'active_support/core_ext/kernel/reporting'

require 'active_support/core_ext/string/encoding'
if "ruby".encoding_aware?
  # These are the normal settings that will be set up by Railties
  # TODO: Have these tests support other combinations of these values
  silence_warnings do
    Encoding.default_internal = "UTF-8"
    Encoding.default_external = "UTF-8"
  end
end

lib = File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'test/unit'
require 'action_mailer'
require 'action_mailer/test_case'

silence_warnings do
  # These external dependencies have warnings :/
  require 'mail'
end

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

ActiveSupport::Deprecation.silenced = true
