use "Rack::Lock", :if => lambda {
  !ActionController::Base.allow_concurrency
}

use "ActionDispatch::Failsafe"
use "ActionDispatch::ShowExceptions", lambda { ActionController::Base.consider_all_requests_local }
use "ActionDispatch::Rescue", lambda {
  controller = (::ApplicationController rescue ActionController::Base)
  controller.method(:rescue_action)
}

use lambda { ActionController::Base.session_store },
    lambda { ActionController::Base.session_options }

use "ActionDispatch::ParamsParser"
use "Rack::MethodOverride"
use "Rack::Head"