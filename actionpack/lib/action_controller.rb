module ActionController
  autoload :Base,                 "action_controller/base/base"
  autoload :ConditionalGet,       "action_controller/base/conditional_get"
  autoload :HideActions,          "action_controller/base/hide_actions"
  autoload :Http,                 "action_controller/base/http"
  autoload :Layouts,              "action_controller/base/layouts"
  autoload :RackConvenience,      "action_controller/base/rack_convenience"
  autoload :Rails2Compatibility,  "action_controller/base/compatibility"
  autoload :Redirector,           "action_controller/base/redirector"
  autoload :Renderer,             "action_controller/base/renderer"
  autoload :RenderOptions,        "action_controller/base/render_options"
  autoload :Renderers,            "action_controller/base/render_options"
  autoload :Rescue,               "action_controller/base/rescuable"
  autoload :Testing,              "action_controller/base/testing"
  autoload :UrlFor,               "action_controller/base/url_for"
  autoload :Session,              "action_controller/base/session"
  autoload :Helpers,              "action_controller/base/helpers"

  # Ported modules
  # require 'action_controller/routing'
  autoload :Caching,           'action_controller/caching'
  autoload :Dispatcher,        'action_controller/dispatch/dispatcher'
  autoload :Integration,       'action_controller/testing/integration'
  autoload :MimeResponds,      'action_controller/base/mime_responds'
  autoload :PolymorphicRoutes, 'action_controller/routing/generation/polymorphic_routes'
  autoload :RecordIdentifier,  'action_controller/record_identifier'
  autoload :Resources,         'action_controller/routing/resources'
  autoload :SessionManagement, 'action_controller/base/session_management'
  autoload :TestCase,          'action_controller/testing/test_case'
  autoload :TestProcess,       'action_controller/testing/process'
  autoload :UrlRewriter,       'action_controller/routing/generation/url_rewriter'
  autoload :UrlWriter,         'action_controller/routing/generation/url_rewriter'

  autoload :Verification,             'action_controller/base/verification'
  autoload :Flash,                    'action_controller/base/flash'
  autoload :RequestForgeryProtection, 'action_controller/base/request_forgery_protection'
  autoload :Streaming,                'action_controller/base/streaming'
  autoload :HttpAuthentication,       'action_controller/base/http_authentication'
  autoload :FilterParameterLogging,   'action_controller/base/filter_parameter_logging'
  autoload :Translation,              'action_controller/translation'
  autoload :Cookies,                  'action_controller/base/cookies'

  autoload :ActionControllerError,    'action_controller/base/exceptions'
  autoload :SessionRestoreError,      'action_controller/base/exceptions'
  autoload :RenderError,              'action_controller/base/exceptions'
  autoload :RoutingError,             'action_controller/base/exceptions'
  autoload :MethodNotAllowed,         'action_controller/base/exceptions'
  autoload :NotImplemented,           'action_controller/base/exceptions'
  autoload :UnknownController,        'action_controller/base/exceptions'
  autoload :MissingFile,              'action_controller/base/exceptions'
  autoload :RenderError,              'action_controller/base/exceptions'
  autoload :SessionOverflowError,     'action_controller/base/exceptions'
  autoload :UnknownHttpMethod,        'action_controller/base/exceptions'

  require 'action_controller/routing'
end

autoload :HTML, 'action_controller/vendor/html-scanner'
autoload :AbstractController, 'action_controller/abstract'

require 'action_dispatch'
require 'action_view'
