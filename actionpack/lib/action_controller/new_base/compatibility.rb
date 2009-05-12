module ActionController
  module Rails2Compatibility
    extend ActiveSupport::DependencyModule
  
    # Temporary hax
    included do
      ::ActionController::UnknownAction = ::AbstractController::ActionNotFound
      ::ActionController::DoubleRenderError = ::AbstractController::DoubleRenderError
      
      cattr_accessor :session_options
      self.send(:class_variable_set, "@@session_options", {})
      
      cattr_accessor :allow_concurrency
      self.send(:class_variable_set, "@@allow_concurrency", false)
      
      cattr_accessor :param_parsers
      self.send(:class_variable_set, "@@param_parsers", { Mime::MULTIPART_FORM   => :multipart_form,
                          Mime::URL_ENCODED_FORM => :url_encoded_form,
                          Mime::XML              => :xml_simple,
                          Mime::JSON             => :json })
                          
      cattr_accessor :relative_url_root
      self.send(:class_variable_set, "@@relative_url_root", ENV['RAILS_RELATIVE_URL_ROOT'])
      
      cattr_accessor :default_charset
      self.send(:class_variable_set, "@@default_charset", "utf-8")
      
      cattr_reader :protected_instance_variables
      self.send(:class_variable_set, "@@protected_instance_variables", %w(@assigns @performed_redirect @performed_render @variables_added @request_origin @url @parent_controller
                                          @action_name @before_filter_chain_aborted @action_cache_path @_headers @_params
                                          @_flash @_response))
    end
    
    module ClassMethods
      def protect_from_forgery() end
      def consider_all_requests_local() end
      def rescue_action(env)
        raise env["action_dispatch.rescue.exception"]
      end
    end
  
    def render_to_body(options)
      if options.is_a?(Hash) && options.key?(:template)
        options[:template].sub!(/^\//, '')
      end
      
      options[:text] = nil if options[:nothing] == true

      super
    end
      
    def _layout_for_name(name)
      name &&= name.sub(%r{^/?layouts/}, '')
      super
    end
   
  end
end