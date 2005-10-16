require 'action_controller/session/drb_store'
require 'action_controller/session/mem_cache_store'
if Object.const_defined?(:ActiveRecord)
  require 'action_controller/session/active_record_store'
end

module ActionController #:nodoc:
  module SessionManagement #:nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
      base.send(:alias_method, :process_without_session_management_support, :process)
      base.send(:alias_method, :process, :process_with_session_management_support)
      base.after_filter(:clear_persistant_model_associations)
    end

    module ClassMethods
      # Set the session store to be used for keeping the session data between requests. The default is using the
      # file system, but you can also specify one of the other included stores (:active_record_store, :drb_store, 
      # :mem_cache_store, or :memory_store) or use your own class.
      def session_store=(store)
        ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS[:database_manager] =
          store.is_a?(Symbol) ? CGI::Session.const_get(store == :drb_store ? "DRbStore" : store.to_s.camelize) : store
      end

      # Returns the session store class currently used.
      def session_store
        ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS[:database_manager]
      end

      # Returns the hash used to configure the session. Example use:
      #
      #   ActionController::Base.session_options[:session_secure] = true # session only available over HTTPS
      def session_options
        ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
      end
      
      # Specify how sessions ought to be managed for a subset of the actions on
      # the controller. Like filters, you can specify <tt>:only</tt> and
      # <tt>:except</tt> clauses to restrict the subset, otherwise options
      # apply to all actions on this controller.
      #
      # The session options are inheritable, as well, so if you specify them in
      # a parent controller, they apply to controllers that extend the parent.
      #
      # Usage:
      #
      #   # turn off session management for all actions.
      #   session :off
      #
      #   # turn off session management for all actions _except_ foo and bar.
      #   session :off, :except => %w(foo bar)
      #
      #   # turn off session management for only the foo and bar actions.
      #   session :off, :only => %w(foo bar)
      #
      #   # the session will only work over HTTPS, but only for the foo action
      #   session :only => :foo, :session_secure => true
      #
      #   # the session will only be disabled for 'foo', and only if it is
      #   # requested as a web service
      #   session :off, :only => :foo,
      #           :if => Proc.new { |req| req.parameters[:ws] }
      #
      # All session options described for ActionController::Base.process_cgi
      # are valid arguments.
      def session(*args)
        options = Hash === args.last ? args.pop : {}

        options[:disabled] = true if !args.empty?
        options[:only] = [*options[:only]].map { |o| o.to_s } if options[:only]
        options[:except] = [*options[:except]].map { |o| o.to_s } if options[:except]
        if options[:only] && options[:except]
          raise ArgumentError, "only one of either :only or :except are allowed"
        end

        write_inheritable_array("session_options", [options])
      end

      def cached_session_options #:nodoc:
        @session_options ||= read_inheritable_attribute("session_options") || []
      end

      def session_options_for(request, action) #:nodoc:
        if (session_options = cached_session_options).empty?
          {}
        else
          options = {}

          action = action.to_s
          session_options.each do |opts|
            next if opts[:if] && !opts[:if].call(request)
            if opts[:only] && opts[:only].include?(action)
              options.merge!(opts)
            elsif opts[:except] && !opts[:except].include?(action)
              options.merge!(opts)
            elsif !opts[:only] && !opts[:except]
              options.merge!(opts)
            end
          end
          
          if options.empty? then options
          else
            options.delete :only
            options.delete :except
            options.delete :if
            options[:disabled] ? false : options
          end
        end
      end
    end

    def process_with_session_management_support(request, response, method = :perform_action, *arguments) #:nodoc:
      action = request.parameters["action"] || "index"
      request.session_options = self.class.session_options_for(request, action)
      process_without_session_management_support(request, response, method, *arguments)
    end
  
    private
      def clear_persistant_model_associations #:doc:
        if session = @session.instance_variable_get("@data")
          session.each { |key, obj| obj.clear_association_cache if obj.respond_to?(:clear_association_cache) }
        end
      end
  end
end
