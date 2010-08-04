require 'abstract_controller'
require 'action_dispatch'

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
    autoload :Flash
    autoload :Head
    autoload :Helpers
    autoload :HideActions
    autoload :HttpAuthentication
    autoload :ImplicitRender
    autoload :Instrumentation
    autoload :MimeResponds
    autoload :RackDelegation
    autoload :Redirecting
    autoload :Renderers
    autoload :Rendering
    autoload :RequestForgeryProtection
    autoload :Rescue
    autoload :Responder
    autoload :SessionManagement
    autoload :Streaming
    autoload :Testing
    autoload :UrlFor
  end

  autoload :Dispatcher,      'action_controller/deprecated/dispatcher'
  autoload :UrlWriter,       'action_controller/deprecated/url_writer'
  autoload :UrlRewriter,     'action_controller/deprecated/url_writer'
  autoload :Integration,     'action_controller/deprecated/integration_test'
  autoload :IntegrationTest, 'action_controller/deprecated/integration_test'
  autoload :PerformanceTest, 'action_controller/deprecated/performance_test'
  autoload :Routing,         'action_controller/deprecated'
  autoload :TestCase,        'action_controller/test_case'

  eager_autoload do
    autoload :RecordIdentifier

    # TODO: Don't autoload exceptions, setup explicit
    # requires for files that need them
    autoload_at "action_controller/metal/exceptions" do
      autoload :ActionControllerError
      autoload :RenderError
      autoload :RoutingError
      autoload :MethodNotAllowed
      autoload :NotImplemented
      autoload :UnknownController
      autoload :MissingFile
      autoload :RenderError
      autoload :SessionOverflowError
      autoload :UnknownHttpMethod
    end
  end
end

# All of these simply register additional autoloads
require 'action_view'
require 'action_controller/vendor/html-scanner'

# Common Active Support usage in Action Controller
require 'active_support/concern'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/load_error'
require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/name_error'
require 'active_support/inflector'
