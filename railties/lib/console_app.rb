require 'action_controller/integration_test'

# work around the at_exit hook in test/unit, which kills IRB
Test::Unit.run = true

# have to use :require dependencies mechanism with the integration test stuff,
# or things start acting really wierd from request to request.
Dependencies.mechanism = :require

# reference the global "app" instance, created on demand. To recreate the
# instance, pass a non-false value as the parameter.
def app(create=false)
  @app_integration_instance = nil if create
  @app_integration_instance ||= new_session do |sess|
    sess.host! "www.example.test"
  end
end

# create a new session. If a block is given, the new session will be yielded
# to the block before being returned.
def new_session
  session = ActionController::Integration::Session.new
  yield session if block_given?
  session
end

#reloads the environment
def reload!
  puts "Reloading..."
  Dispatcher.reset_application!
end