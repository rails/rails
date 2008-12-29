use "ActionController::Lock", :if => lambda {
  !ActionController::Base.allow_concurrency
}

use "ActionController::Failsafe"

use "ActiveRecord::QueryCache", :if => lambda { defined?(ActiveRecord) }

["ActionController::Session::CookieStore",
 "ActionController::Session::MemCacheStore",
 "ActiveRecord::SessionStore"].each do |store|
   use(store, ActionController::Base.session_options,
      :if => lambda {
        if session_store = ActionController::Base.session_store
          session_store.name == store
        end
      }
    )
end

use ActionController::VerbPiggybacking
