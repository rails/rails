use "Rack::Lock", :if => lambda {
  !ActionController::Base.allow_concurrency
}

use "ActionDispatch::ShowExceptions", lambda { ActionController::Base.consider_all_requests_local }
use "ActionDispatch::Callbacks", lambda { ActionController::Dispatcher.prepare_each_request }
use "ActionDispatch::Rescue", lambda {
  controller = (::ApplicationController rescue ActionController::Base)
  # TODO: Replace with controller.action(:_rescue_action)
  controller.method(:rescue_action)
}

use lambda { ActionController::Base.session_store },
    lambda { ActionController::Base.session_options }

use "ActionDispatch::ParamsParser"
use "Rack::MethodOverride"
use "Rack::Head"