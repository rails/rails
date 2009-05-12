module ActionController
  autoload :Base,                 "action_controller/new_base/base"
  autoload :ConditionalGet,       "action_controller/new_base/conditional_get"
  autoload :HideActions,          "action_controller/new_base/hide_actions"
  autoload :Http,                 "action_controller/new_base/http"
  autoload :Layouts,              "action_controller/new_base/layouts"
  autoload :Rails2Compatibility,  "action_controller/new_base/compatibility"
  autoload :Renderer,             "action_controller/new_base/renderer"
  autoload :Testing,              "action_controller/new_base/testing"
  autoload :UrlFor,               "action_controller/new_base/url_for"
  
  # Ported modules
  # require 'action_controller/routing'
  autoload :Dispatcher,        'action_controller/dispatch/dispatcher'
  autoload :PolymorphicRoutes, 'action_controller/routing/generation/polymorphic_routes'
  autoload :RecordIdentifier,  'action_controller/record_identifier'
  autoload :Resources,         'action_controller/routing/resources'
  autoload :SessionManagement, 'action_controller/base/session_management'
  autoload :TestCase,          'action_controller/testing/test_case'
  autoload :UrlRewriter,       'action_controller/routing/generation/url_rewriter'
  autoload :UrlWriter,         'action_controller/routing/generation/url_rewriter'
  
  require 'action_controller/routing'
end

require 'action_dispatch'
require 'action_view'