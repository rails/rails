module ActionController
  class Base < Metal
    abstract!

    include AbstractController::Callbacks
    include AbstractController::Layouts

    include ActionController::Helpers
    include ActionController::HideActions
    include ActionController::UrlFor
    include ActionController::Redirecting
    include ActionController::Rendering
    include ActionController::Renderers::All
    include ActionController::ConditionalGet
    include ActionController::RackDelegation
    include ActionController::Logger
    include ActionController::Configuration

    # Legacy modules
    include SessionManagement
    include ActionController::Caching
    include ActionController::MimeResponds

    # Rails 2.x compatibility
    include ActionController::Compatibility

    include ActionController::Cookies
    include ActionController::Flash
    include ActionController::Verification
    include ActionController::RequestForgeryProtection
    include ActionController::Streaming
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ActionController::HttpAuthentication::Digest::ControllerMethods
    include ActionController::FilterParameterLogging
    include ActionController::Translation

    # TODO: Extract into its own module
    # This should be moved together with other normalizing behavior
    module ImplicitRender
      def send_action(*)
        ret = super
        default_render unless response_body
        ret
      end

      def default_render
        render
      end

      def method_for_action(action_name)
        super || begin
          if template_exists?(action_name.to_s, {:formats => formats}, :_prefix => controller_path)
            "default_render"
          end
        end
      end
    end

    include ImplicitRender

    include ActionController::Rescue

    def self.inherited(klass)
      ::ActionController::Base.subclasses << klass.to_s
      super
    end

    def self.subclasses
      @subclasses ||= []
    end

    def _normalize_options(action = nil, options = {}, &blk)
      if action.is_a?(Hash)
        options, action = action, nil
      elsif action.is_a?(String) || action.is_a?(Symbol)
        key = case action = action.to_s
        when %r{^/} then :file
        when %r{/}  then :template
        else             :action
        end
        options.merge! key => action
      elsif action
        options.merge! :partial => action
      end

      if options.key?(:action) && options[:action].to_s.index("/")
        options[:template] = options.delete(:action)
      end

      if options[:status]
        options[:status] = Rack::Utils.status_code(options[:status])
      end

      options[:update] = blk if block_given?
      options
    end

    def render(action = nil, options = {}, &blk)
      options = _normalize_options(action, options, &blk)
      super(options)
    end

    def render_to_string(action = nil, options = {}, &blk)
      options = _normalize_options(action, options, &blk)
      super(options)
    end
  end
end
