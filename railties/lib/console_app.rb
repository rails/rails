require 'action_controller/integration_test'

# work around the at_exit hook in test/unit, which kills IRB
Test::Unit.run = true

def app(create=false)
  @app_integration_instance = nil if create
  unless @app_integration_instance
    @app_integration_instance = ActionController::Integration::Session.new
    @app_integration_instance.host! "www.example.test"
  end
  @app_integration_instance
end