module ActionController #:nodoc:
  module SessionManagement #:nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
      base.class_eval do
        alias_method :process_without_session_management_support, :process
        alias_method :process, :process_with_session_management_support
      end
    end

    module ClassMethods
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

      def session_options_for(request, action) #:nodoc:
        options = {}

        action = action.to_s
        (read_inheritable_attribute("session_options") || []).each do |opts|
          next if opts[:if] && !opts[:if].call(request)
          if opts[:only] && opts[:only].include?(action)
            options.merge!(opts)
          elsif opts[:except] && !opts[:except].include?(action)
            options.merge!(opts)
          elsif !opts[:only] && !opts[:except]
            options.merge!(opts)
          end
        end

        options.delete :only
        options.delete :except
        options.delete :if

        options[:disabled] ? false : options
      end
    end

    def process_with_session_management_support(request, response, method = :perform_action, *arguments) #:nodoc:
      action = request.parameters["action"] || "index"
      request.session_options = self.class.session_options_for(request, action)
      process_without_session_management_support(request, response, method, *arguments)
    end
  end
end
