module ActionController
  autoload :Base,                 "action_controller/base"
  autoload :Benchmarking,         "action_controller/metal/benchmarking"
  autoload :ConditionalGet,       "action_controller/metal/conditional_get"
  autoload :Helpers,              "action_controller/metal/helpers"
  autoload :HideActions,          "action_controller/metal/hide_actions"
  autoload :Layouts,              "action_controller/metal/layouts"
  autoload :Metal,                "action_controller/metal"
  autoload :Middleware,           "action_controller/middleware"
  autoload :RackConvenience,      "action_controller/metal/rack_convenience"
  autoload :Rails2Compatibility,  "action_controller/metal/compatibility"
  autoload :Redirector,           "action_controller/metal/redirector"
  autoload :RenderingController,  "action_controller/metal/rendering_controller"
  autoload :RenderOptions,        "action_controller/metal/render_options"
  autoload :Rescue,               "action_controller/metal/rescuable"
  autoload :Responder,            "action_controller/metal/responder"
  autoload :Session,              "action_controller/metal/session"
  autoload :Testing,              "action_controller/metal/testing"
  autoload :UrlFor,               "action_controller/metal/url_for"

  autoload :Caching,           'action_controller/caching'
  autoload :Dispatcher,        'action_controller/dispatch/dispatcher'
  autoload :Integration,       'action_controller/deprecated/integration_test'
  autoload :IntegrationTest,   'action_controller/deprecated/integration_test'
  autoload :MimeResponds,      'action_controller/metal/mime_responds'
  autoload :PerformanceTest,   'action_controller/deprecated/performance_test'
  autoload :PolymorphicRoutes, 'action_controller/polymorphic_routes'
  autoload :RecordIdentifier,  'action_controller/record_identifier'
  autoload :Routing,           'action_controller/deprecated'
  autoload :SessionManagement, 'action_controller/metal/session_management'
  autoload :TestCase,          'action_controller/testing/test_case'
  autoload :TestProcess,       'action_controller/testing/process'
  autoload :UrlRewriter,       'action_controller/url_rewriter'
  autoload :UrlWriter,         'action_controller/url_rewriter'

  autoload :Verification,             'action_controller/metal/verification'
  autoload :Flash,                    'action_controller/metal/flash'
  autoload :RequestForgeryProtection, 'action_controller/metal/request_forgery_protection'
  autoload :Streaming,                'action_controller/metal/streaming'
  autoload :HttpAuthentication,       'action_controller/metal/http_authentication'
  autoload :FilterParameterLogging,   'action_controller/metal/filter_parameter_logging'
  autoload :Translation,              'action_controller/translation'
  autoload :Cookies,                  'action_controller/metal/cookies'

  autoload :ActionControllerError,    'action_controller/metal/exceptions'
  autoload :RenderError,              'action_controller/metal/exceptions'
  autoload :RoutingError,             'action_controller/metal/exceptions'
  autoload :MethodNotAllowed,         'action_controller/metal/exceptions'
  autoload :NotImplemented,           'action_controller/metal/exceptions'
  autoload :UnknownController,        'action_controller/metal/exceptions'
  autoload :MissingFile,              'action_controller/metal/exceptions'
  autoload :RenderError,              'action_controller/metal/exceptions'
  autoload :SessionOverflowError,     'action_controller/metal/exceptions'
  autoload :UnknownHttpMethod,        'action_controller/metal/exceptions'
end

autoload :HTML, 'action_controller/vendor/html-scanner'
autoload :AbstractController, 'abstract_controller'

require 'action_dispatch'
require 'action_view'

# Common ActiveSupport usage in ActionController
require "active_support/concern"
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/load_error'
require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/name_error'
require 'active_support/inflector'
