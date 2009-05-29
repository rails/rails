module ActionController
  autoload :Base,                 "action_controller/new_base/base"
  autoload :ConditionalGet,       "action_controller/new_base/conditional_get"
  autoload :HideActions,          "action_controller/new_base/hide_actions"
  autoload :Http,                 "action_controller/new_base/http"
  autoload :Layouts,              "action_controller/new_base/layouts"
  autoload :RackConvenience,      "action_controller/new_base/rack_convenience"
  autoload :Rails2Compatibility,  "action_controller/new_base/compatibility"
  autoload :Redirector,           "action_controller/new_base/redirector"
  autoload :Renderer,             "action_controller/new_base/renderer"
  autoload :RenderOptions,        "action_controller/new_base/render_options"
  autoload :Renderers,            "action_controller/new_base/render_options"
  autoload :Rescue,               "action_controller/new_base/rescuable"
  autoload :Testing,              "action_controller/new_base/testing"
  autoload :UrlFor,               "action_controller/new_base/url_for"
  autoload :Session,              "action_controller/new_base/session"
  autoload :Helpers,              "action_controller/new_base/helpers"

  # Ported modules
  # require 'action_controller/routing'
  autoload :Caching,           'action_controller/caching'
  autoload :Dispatcher,        'action_controller/dispatch/dispatcher'
  autoload :MimeResponds,      'action_controller/base/mime_responds'
  autoload :PolymorphicRoutes, 'action_controller/routing/generation/polymorphic_routes'
  autoload :RecordIdentifier,  'action_controller/record_identifier'
  autoload :Resources,         'action_controller/routing/resources'
  autoload :SessionManagement, 'action_controller/base/session_management'
  autoload :TestCase,          'action_controller/testing/test_case'
  autoload :UrlRewriter,       'action_controller/routing/generation/url_rewriter'
  autoload :UrlWriter,         'action_controller/routing/generation/url_rewriter'

  autoload :Verification,             'action_controller/base/verification'
  autoload :Flash,                    'action_controller/base/chained/flash'
  autoload :RequestForgeryProtection, 'action_controller/base/request_forgery_protection'
  autoload :Streaming,                'action_controller/base/streaming'
  autoload :HttpAuthentication,       'action_controller/base/http_authentication'
  autoload :FilterParameterLogging,   'action_controller/base/filter_parameter_logging'
  autoload :Translation,              'action_controller/translation'
  autoload :Cookies,                  'action_controller/base/cookies'

  require 'action_controller/routing'
end

autoload :HTML, 'action_controller/vendor/html-scanner'

require 'action_dispatch'
require 'action_view'
