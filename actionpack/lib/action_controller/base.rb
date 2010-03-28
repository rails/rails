module ActionController
  class Base < Metal
    abstract!

    include AbstractController::Layouts
    include AbstractController::Translation

    include ActionController::Helpers
    
    include ActionController::HideActions
    include ActionController::UrlFor
    include ActionController::Redirecting
    include ActionController::Rendering
    include ActionController::Renderers::All
    include ActionController::ConditionalGet
    include ActionController::RackDelegation

    # Legacy modules
    include SessionManagement
    include ActionController::Caching
    include ActionController::MimeResponds
    include ActionController::PolymorphicRoutes

    # Rails 2.x compatibility
    include ActionController::Compatibility
    include ActionController::ImplicitRender

    include ActionController::Cookies
    include ActionController::Flash
    include ActionController::Verification
    include ActionController::RequestForgeryProtection
    include ActionController::Streaming
    include ActionController::RecordIdentifier
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ActionController::HttpAuthentication::Digest::ControllerMethods

    # Add instrumentations hooks at the bottom, to ensure they instrument
    # all the methods properly.
    include ActionController::Instrumentation

    # Before callbacks should also be executed the earliest as possible, so
    # also include them at the bottom.
    include AbstractController::Callbacks

    # The same with rescue, append it at the end to wrap as much as possible.
    include ActionController::Rescue

    def self.inherited(klass)
      ::ActionController::Base.subclasses << klass.to_s
      super
      klass.helper :all
    end

    def self.subclasses
      @subclasses ||= []
    end

    # This method has been moved to ActionDispatch::Request.filter_parameters
    def self.filter_parameter_logging(*args, &block)
      ActiveSupport::Deprecation.warn("Setting filter_parameter_logging in ActionController is deprecated and has no longer effect, please set 'config.filter_parameters' in config/application.rb instead", caller)
      filter = Rails.application.config.filter_parameters
      filter.concat(args)
      filter << block if block
      filter
    end

    ActionController.run_base_hooks(self)

  end
end

require "action_controller/deprecated/base"
