require "action_controller/log_subscriber"

module ActionController
  class Base < Metal
    abstract!

    def self.without_modules(*modules)
      modules = modules.map do |m|
        m.is_a?(Symbol) ? ActionController.const_get(m) : m
      end

      MODULES - modules
    end

    MODULES = [
      AbstractController::Layouts,
      AbstractController::Translation,
      AbstractController::AssetPaths,

      Helpers,
      HideActions,
      UrlFor,
      Redirecting,
      Rendering,
      Renderers::All,
      ConditionalGet,
      RackDelegation,
      SessionManagement,
      Caching,
      MimeResponds,
      ImplicitRender,

      Cookies,
      Flash,
      RequestForgeryProtection,
      Streaming,
      RecordIdentifier,
      HttpAuthentication::Basic::ControllerMethods,
      HttpAuthentication::Digest::ControllerMethods,
      HttpAuthentication::Token::ControllerMethods,

      # Add instrumentations hooks at the bottom, to ensure they instrument
      # all the methods properly.
      Instrumentation,

      # Before callbacks should also be executed the earliest as possible, so
      # also include them at the bottom.
      AbstractController::Callbacks,

      # The same with rescue, append it at the end to wrap as much as possible.
      Rescue
    ]

    MODULES.each do |mod|
      include mod
    end

    # Rails 2.x compatibility
    include ActionController::Compatibility

    def self.inherited(klass)
      super
      klass.helper :all
    end

    ActiveSupport.run_load_hooks(:action_controller, self)
  end
end

require "action_controller/deprecated/base"
