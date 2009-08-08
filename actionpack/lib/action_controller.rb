module ActionController
  autoload :Base,                 "action_controller/base"
  autoload :ConditionalGet,       "action_controller/metal/conditional_get"
  autoload :HideActions,          "action_controller/metal/hide_actions"
  autoload :Metal,                "action_controller/metal"
  autoload :Layouts,              "action_controller/metal/layouts"
  autoload :RackConvenience,      "action_controller/metal/rack_convenience"
  autoload :Rails2Compatibility,  "action_controller/metal/compatibility"
  autoload :Redirector,           "action_controller/metal/redirector"
  autoload :RenderingController,  "action_controller/metal/rendering_controller"
  autoload :RenderOptions,        "action_controller/metal/render_options"
  autoload :Rescue,               "action_controller/metal/rescuable"
  autoload :Responder,            "action_controller/metal/responder"
  autoload :Testing,              "action_controller/metal/testing"
  autoload :UrlFor,               "action_controller/metal/url_for"
  autoload :Session,              "action_controller/metal/session"
  autoload :Helpers,              "action_controller/metal/helpers"

  # Ported modules
  # require 'action_controller/routing'
  autoload :Caching,           'action_controller/caching'
  autoload :Dispatcher,        'action_controller/dispatch/dispatcher'
  autoload :Integration,       'action_controller/testing/integration'
  autoload :MimeResponds,      'action_controller/metal/mime_responds'
  autoload :PolymorphicRoutes, 'action_controller/routing/generation/polymorphic_routes'
  autoload :RecordIdentifier,  'action_controller/record_identifier'
  autoload :Resources,         'action_controller/routing/resources'
  autoload :SessionManagement, 'action_controller/metal/session_management'
  autoload :TestCase,          'action_controller/testing/test_case'
  autoload :TestProcess,       'action_controller/testing/process'
  autoload :UrlRewriter,       'action_controller/routing/generation/url_rewriter'
  autoload :UrlWriter,         'action_controller/routing/generation/url_rewriter'

  autoload :Verification,             'action_controller/metal/verification'
  autoload :Flash,                    'action_controller/metal/flash'
  autoload :RequestForgeryProtection, 'action_controller/metal/request_forgery_protection'
  autoload :Streaming,                'action_controller/metal/streaming'
  autoload :HttpAuthentication,       'action_controller/metal/http_authentication'
  autoload :FilterParameterLogging,   'action_controller/metal/filter_parameter_logging'
  autoload :Translation,              'action_controller/translation'
  autoload :Cookies,                  'action_controller/metal/cookies'

  autoload :ActionControllerError,    'action_controller/metal/exceptions'
  autoload :SessionRestoreError,      'action_controller/metal/exceptions'
  autoload :RenderError,              'action_controller/metal/exceptions'
  autoload :RoutingError,             'action_controller/metal/exceptions'
  autoload :MethodNotAllowed,         'action_controller/metal/exceptions'
  autoload :NotImplemented,           'action_controller/metal/exceptions'
  autoload :UnknownController,        'action_controller/metal/exceptions'
  autoload :MissingFile,              'action_controller/metal/exceptions'
  autoload :RenderError,              'action_controller/metal/exceptions'
  autoload :SessionOverflowError,     'action_controller/metal/exceptions'
  autoload :UnknownHttpMethod,        'action_controller/metal/exceptions'

  autoload :Routing,                  'action_controller/routing'
end

autoload :HTML, 'action_controller/vendor/html-scanner'
autoload :AbstractController, 'abstract_controller'

autoload :Rack,                       'action_dispatch'
autoload :ActionDispatch,             'action_dispatch'
autoload :ActionView,                 'action_view'

# Common ActiveSupport usage in ActionController
require "active_support/concern"
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/load_error'
require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/name_error'
require 'active_support/inflector'
