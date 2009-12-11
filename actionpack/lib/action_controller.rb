require "active_support"

module ActionController
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Caching
  autoload :PolymorphicRoutes
  autoload :RecordIdentifier
  autoload :UrlRewriter
  autoload :Translation
  autoload :Metal
  autoload :Middleware

  autoload_under "metal" do
    autoload :Benchmarking
    autoload :ConditionalGet
    autoload :Configuration
    autoload :Head
    autoload :Helpers
    autoload :HideActions
    autoload :Layouts
    autoload :MimeResponds
    autoload :RackConvenience
    autoload :Compatibility
    autoload :Redirector
    autoload :RenderingController
    autoload :RenderOptions
    autoload :Rescue
    autoload :Responder
    autoload :Session
    autoload :SessionManagement
    autoload :UrlFor
    autoload :Verification
    autoload :Flash
    autoload :RequestForgeryProtection
    autoload :Streaming
    autoload :HttpAuthentication
    autoload :FilterParameterLogging
    autoload :Cookies
  end

  autoload :Dispatcher,               'action_controller/dispatch/dispatcher'
  autoload :PerformanceTest,          'action_controller/deprecated/performance_test'
  autoload :Routing,                  'action_controller/deprecated'
  autoload :Integration,              'action_controller/deprecated/integration_test'
  autoload :IntegrationTest,          'action_controller/deprecated/integration_test'

  autoload :UrlWriter,                'action_controller/url_rewriter'

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

# All of these simply register additional autoloads
require 'abstract_controller'
require 'action_dispatch'
require 'action_view'
require 'action_controller/vendor/html-scanner'

# Common ActiveSupport usage in ActionController
require "active_support/concern"
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/load_error'
require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/name_error'
require 'active_support/inflector'
