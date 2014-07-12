require 'active_support/rails'
require 'abstract_controller'
require 'action_dispatch'
require 'action_controller/metal/live'
require 'action_controller/metal/strong_parameters'

module ActionController
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Caching
  autoload :Metal
  autoload :Middleware

  autoload_under "metal" do
    autoload :Compatibility
    autoload :ConditionalGet
    autoload :Cookies
    autoload :DataStreaming
    autoload :Flash
    autoload :ForceSSL
    autoload :Head
    autoload :Helpers
    autoload :HideActions
    autoload :HttpAuthentication
    autoload :ImplicitRender
    autoload :Instrumentation
    autoload :MimeResponds
    autoload :ParamsWrapper
    autoload :RackDelegation
    autoload :Redirecting
    autoload :Renderers
    autoload :Rendering
    autoload :RequestForgeryProtection
    autoload :Rescue
    autoload :Responder
    autoload :Streaming
    autoload :StrongParameters
    autoload :Testing
    autoload :UrlFor
  end

  autoload :TestCase,           'action_controller/test_case'
  autoload :TemplateAssertions, 'action_controller/test_case'

  def self.eager_load!
    super
    ActionController::Caching.eager_load!
  end
end

# Common Active Support usage in Action Controller
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/load_error'
require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/name_error'
require 'active_support/core_ext/uri'
require 'active_support/inflector'
