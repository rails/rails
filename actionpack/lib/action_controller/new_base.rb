module ActionController
  autoload :Base,                 "action_controller/new_base/base"
  autoload :ConditionalGet,       "action_controller/new_base/conditional_get"
  autoload :HideActions,          "action_controller/new_base/hide_actions"
  autoload :Http,                 "action_controller/new_base/http"
  autoload :Layouts,              "action_controller/new_base/layouts"
  autoload :Rails2Compatibility,  "action_controller/new_base/compatibility"
  autoload :Redirector,           "action_controller/new_base/redirector"
  autoload :Renderer,             "action_controller/new_base/renderer"
  autoload :Rescue,               "action_controller/new_base/rescuable"
  autoload :Testing,              "action_controller/new_base/testing"
  autoload :UrlFor,               "action_controller/new_base/url_for"
  autoload :Session,              "action_controller/new_base/session"

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

  autoload :Verification, 'action_controller/base/verification'
  autoload :Flash,        'action_controller/base/chained/flash'

  require 'action_controller/routing'
end

require 'action_dispatch'
require 'action_view'