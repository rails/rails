use "Rack::Lock", :if => lambda {
  !ActionController::Base.allow_concurrency
}

use "ActionDispatch::Failsafe"

use lambda { ActionController::Base.session_store },
    lambda { ActionController::Base.session_options }

use "ActionDispatch::RewindableInput"
use "ActionDispatch::ParamsParser"
use "Rack::MethodOverride"
use "Rack::Head"
