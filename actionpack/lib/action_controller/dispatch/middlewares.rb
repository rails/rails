use "Rack::Lock", :if => lambda {
  !ActionController::Base.allow_concurrency
}

use "ActionDispatch::ShowExceptions", lambda { ActionController::Base.consider_all_requests_local }
use "ActionDispatch::Callbacks", lambda { ActionController::Dispatcher.prepare_each_request }

# TODO: Redirect global exceptions somewhere?
# use "ActionDispatch::Rescue"

use lambda { ActionController::Base.session_store },
    lambda { ActionController::Base.session_options }

use "ActionDispatch::ParamsParser"
use "Rack::MethodOverride"
use "Rack::Head"
