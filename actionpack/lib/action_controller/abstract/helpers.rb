module AbstractController
  module Helpers
    extend ActiveSupport::DependencyModule

    depends_on Renderer

    included do
      extlib_inheritable_accessor :master_helper_module
      self.master_helper_module = Module.new
    end

    def _action_view
      @_action_view ||= begin
        av = super
        av.helpers.send(:include, master_helper_module)
        av
      end
    end
    
    module ClassMethods
      def inherited(klass)
        klass.master_helper_module = Module.new
        klass.master_helper_module.__send__ :include, master_helper_module
        
        super
      end

      # Makes all the (instance) methods in the helper module available to templates rendered through this controller.
      # See ActionView::Helpers (link:classes/ActionView/Helpers.html) for more about making your own helper modules
      # available to the templates.
      def add_template_helper(mod)
        master_helper_module.module_eval { include mod }
      end

      # Declare a controller method as a helper. For example, the following
      # makes the +current_user+ controller method available to the view:
      #   class ApplicationController < ActionController::Base
      #     helper_method :current_user, :logged_in?
      #
      #     def current_user
      #       @current_user ||= User.find_by_id(session[:user])
      #     end
      #
      #      def logged_in?
      #        current_user != nil
      #      end
      #   end
      #
      # In a view:
      #  <% if logged_in? -%>Welcome, <%= current_user.name %><% end -%>
      def helper_method(*meths)
        meths.flatten.each do |meth|
          master_helper_module.class_eval <<-ruby_eval, __FILE__, __LINE__ + 1
            def #{meth}(*args, &blk)
              controller.send(%(#{meth}), *args, &blk)
            end
          ruby_eval
        end
      end
      
      def helper(*args, &block)
        args.flatten.each do |arg|
          case arg
          when Module
            add_template_helper(arg)
          end
        end
        master_helper_module.module_eval(&block) if block_given?
      end
    end
    
  end
end