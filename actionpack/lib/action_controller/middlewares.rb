use "Rack::Lock", :if => lambda {
  !ActionController::Base.allow_concurrency
}

use "ActionController::Failsafe"

use lambda { ActionController::Base.session_store },
    lambda { ActionController::Base.session_options }

use "ActionController::ParamsParser"
use "Rack::MethodOverride"
use "Rack::Head"
