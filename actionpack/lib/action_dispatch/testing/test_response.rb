module ActionDispatch
  # Integration test methods such as ActionDispatch::Integration::Session#get
  # and ActionDispatch::Integration::Session#post return objects of class
  # TestResponse, which represent the HTTP response results of the requested
  # controller actions.
  #
  # See Response for more information on controller response objects.
  class TestResponse < Response
    def self.from_response(response)
      new.tap do |resp|
        resp.status  = response.status
        resp.headers = response.headers
        resp.body    = response.body
      end
    end

    module DeprecatedHelpers
      def template
        ActiveSupport::Deprecation.warn("response.template has been deprecated. Use controller.template instead", caller)
        @template
      end
      attr_writer :template

      def session
        ActiveSupport::Deprecation.warn("response.session has been deprecated. Use request.session instead", caller)
        @request.session
      end

      def assigns
        ActiveSupport::Deprecation.warn("response.assigns has been deprecated. Use controller.assigns instead", caller)
        @template.controller.assigns
      end

      def layout
        ActiveSupport::Deprecation.warn("response.layout has been deprecated. Use template.layout instead", caller)
        @template.layout
      end

      def redirected_to
        ::ActiveSupport::Deprecation.warn("response.redirected_to is deprecated. Use response.redirect_url instead", caller)
        redirect_url
      end

      def redirect_url_match?(pattern)
        ::ActiveSupport::Deprecation.warn("response.redirect_url_match? is deprecated. Use assert_match(/foo/, response.redirect_url) instead", caller)
        return false if redirect_url.nil?
        p = Regexp.new(pattern) if pattern.class == String
        p = pattern if pattern.class == Regexp
        return false if p.nil?
        p.match(redirect_url) != nil
      end

      # Returns the template of the file which was used to
      # render this response (or nil)
      def rendered
        ActiveSupport::Deprecation.warn("response.rendered has been deprecated. Use template.rendered instead", caller)
        @template.instance_variable_get(:@_rendered)
      end

      # A shortcut to the flash. Returns an empty hash if no session flash exists.
      def flash
        ActiveSupport::Deprecation.warn("response.flash has been deprecated. Use request.flash instead", caller)
        request.session['flash'] || {}
      end

      # Do we have a flash?
      def has_flash?
        ActiveSupport::Deprecation.warn("response.has_flash? has been deprecated. Use flash.any? instead", caller)
        !flash.empty?
      end

      # Do we have a flash that has contents?
      def has_flash_with_contents?
        ActiveSupport::Deprecation.warn("response.has_flash_with_contents? has been deprecated. Use flash.any? instead", caller)
        !flash.empty?
      end

      # Does the specified flash object exist?
      def has_flash_object?(name=nil)
        ActiveSupport::Deprecation.warn("response.has_flash_object? has been deprecated. Use flash[name] instead", caller)
        !flash[name].nil?
      end

      # Does the specified object exist in the session?
      def has_session_object?(name=nil)
        ActiveSupport::Deprecation.warn("response.has_session_object? has been deprecated. Use session[name] instead", caller)
        !session[name].nil?
      end

      # A shortcut to the template.assigns
      def template_objects
        ActiveSupport::Deprecation.warn("response.template_objects has been deprecated. Use template.assigns instead", caller)
        @template.assigns || {}
      end

      # Does the specified template object exist?
      def has_template_object?(name=nil)
        ActiveSupport::Deprecation.warn("response.has_template_object? has been deprecated. Use tempate.assigns[name].nil? instead", caller)
        !template_objects[name].nil?
      end

      # Returns binary content (downloadable file), converted to a String
      def binary_content
        ActiveSupport::Deprecation.warn("response.binary_content has been deprecated. Use response.body instead", caller)
        body
      end
    end
    include DeprecatedHelpers

    # Was the response successful?
    def success?
      (200..299).include?(response_code)
    end

    # Was the URL not found?
    def missing?
      response_code == 404
    end

    # Were we redirected?
    def redirect?
      (300..399).include?(response_code)
    end

    # Was there a server-side error?
    def error?
      (500..599).include?(response_code)
    end
    alias_method :server_error?, :error?

    # Was there a client client?
    def client_error?
      (400..499).include?(response_code)
    end
  end
end
