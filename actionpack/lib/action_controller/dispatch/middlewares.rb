use "Rack::Lock", :if => lambda {
  !ActionController::Base.allow_concurrency
}

use "ActionDispatch::Failsafe"

["ActionDispatch::Session::CookieStore",
 "ActionDispatch::Session::MemCacheStore",
 "ActiveRecord::SessionStore"].each do |store|
   use(store, ActionController::Base.session_options,
      :if => lambda {
        if session_store = ActionController::Base.session_store
          session_store.name == store
        end
      }
    )
end

use "ActionDispatch::RewindableInput"
use "ActionDispatch::ParamsParser"
use "Rack::MethodOverride"
