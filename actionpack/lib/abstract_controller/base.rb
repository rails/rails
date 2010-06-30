require 'active_support/configurable'
require 'active_support/descendants_tracker'
require 'active_support/core_ext/module/anonymous'

module AbstractController
  class Error < StandardError; end
  class ActionNotFound < StandardError; end

  class Base
    attr_internal :response_body
    attr_internal :action_name

    include ActiveSupport::Configurable
    extend ActiveSupport::DescendantsTracker

    class << self
      attr_reader :abstract
      alias_method :abstract?, :abstract

      # Define a controller as abstract. See internal_methods for more
      # details.
      def abstract!
        @abstract = true
      end

      # A list of all internal methods for a controller. This finds the first
      # abstract superclass of a controller, and gets a list of all public
      # instance methods on that abstract class. Public instance methods of
      # a controller would normally be considered action methods, so we
      # are removing those methods on classes declared as abstract
      # (ActionController::Metal and ActionController::Base are defined
      # as abstract)
      def internal_methods
        controller = self
        controller = controller.superclass until controller.abstract?
        controller.public_instance_methods(true)
      end

      # The list of hidden actions to an empty Array. Defaults to an
      # empty Array. This can be modified by other modules or subclasses
      # to specify particular actions as hidden.
      #
      # ==== Returns
      # Array[String]:: An array of method names that should not be
      #                 considered actions.
      def hidden_actions
        []
      end

      # A list of method names that should be considered actions. This
      # includes all public instance methods on a controller, less
      # any internal methods (see #internal_methods), adding back in
      # any methods that are internal, but still exist on the class
      # itself. Finally, #hidden_actions are removed.
      #
      # ==== Returns
      # Array[String]:: A list of all methods that should be considered
      #                 actions.
      def action_methods
        @action_methods ||= begin
          # All public instance methods of this class, including ancestors
          methods = public_instance_methods(true).map { |m| m.to_s }.to_set -
            # Except for public instance methods of Base and its ancestors
            internal_methods.map { |m| m.to_s } +
            # Be sure to include shadowed public instance methods of this class
            public_instance_methods(false).map { |m| m.to_s } -
            # And always exclude explicitly hidden actions
            hidden_actions

          # Clear out AS callback method pollution
          methods.reject { |method| method =~ /_one_time_conditions/ }
        end
      end

      # Returns the full controller name, underscored, without the ending Controller.
      # For instance, MyApp::MyPostsController would return "my_app/my_posts" for
      # controller_name.
      #
      # ==== Returns
      # String
      def controller_path
        @controller_path ||= name.sub(/Controller$/, '').underscore unless anonymous?
      end
    end

    abstract!

    # Calls the action going through the entire action dispatch stack.
    #
    # The actual method that is called is determined by calling
    # #method_for_action. If no method can handle the action, then an
    # ActionNotFound error is raised.
    #
    # ==== Returns
    # self
    def process(action, *args)
      @_action_name = action_name = action.to_s

      unless action_name = method_for_action(action_name)
        raise ActionNotFound, "The action '#{action}' could not be found for #{self.class.name}" 
      end

      @_response_body = nil

      process_action(action_name, *args)
    end

    # Delegates to the class' #controller_path
    def controller_path
      self.class.controller_path
    end

    def action_methods
      self.class.action_methods
    end

    private

      # Returns true if the name can be considered an action. This can
      # be overridden in subclasses to modify the semantics of what
      # can be considered an action.
      #
      # ==== Parameters
      # name<String>:: The name of an action to be tested
      #
      # ==== Returns
      # TrueClass, FalseClass
      def action_method?(name)
        self.class.action_methods.include?(name)
      end

      # Call the action. Override this in a subclass to modify the
      # behavior around processing an action. This, and not #process,
      # is the intended way to override action dispatching.
      def process_action(method_name, *args)
        send_action(method_name, *args)
      end

      # Actually call the method associated with the action. Override
      # this method if you wish to change how action methods are called,
      # not to add additional behavior around it. For example, you would
      # override #send_action if you want to inject arguments into the
      # method.
      alias send_action send

      # If the action name was not found, but a method called "action_missing"
      # was found, #method_for_action will return "_handle_action_missing".
      # This method calls #action_missing with the current action name.
      def _handle_action_missing
        action_missing(@_action_name)
      end

      # Takes an action name and returns the name of the method that will
      # handle the action. In normal cases, this method returns the same
      # name as it receives. By default, if #method_for_action receives
      # a name that is not an action, it will look for an #action_missing
      # method and return "_handle_action_missing" if one is found.
      #
      # Subclasses may override this method to add additional conditions
      # that should be considered an action. For instance, an HTTP controller
      # with a template matching the action name is considered to exist.
      #
      # If you override this method to handle additional cases, you may
      # also provide a method (like _handle_method_missing) to handle
      # the case.
      #
      # If none of these conditions are true, and method_for_action
      # returns nil, an ActionNotFound exception will be raised.
      #
      # ==== Parameters
      # action_name<String>:: An action name to find a method name for
      #
      # ==== Returns
      # String:: The name of the method that handles the action
      # nil::    No method name could be found. Raise ActionNotFound.
      def method_for_action(action_name)
        if action_method?(action_name) then action_name
        elsif respond_to?(:action_missing, true) then "_handle_action_missing"
        end
      end
  end
end
