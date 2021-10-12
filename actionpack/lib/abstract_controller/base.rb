# frozen_string_literal: true

require "abstract_controller/error"
require "active_support/configurable"
require "active_support/descendants_tracker"
require "active_support/core_ext/module/anonymous"
require "active_support/core_ext/module/attr_internal"

module AbstractController
  # Raised when a non-existing controller action is triggered.
  class ActionNotFound < StandardError
    attr_reader :controller, :action # :nodoc:

    def initialize(message = nil, controller = nil, action = nil) # :nodoc:
      @controller = controller
      @action = action
      super(message)
    end

    if defined?(DidYouMean::Correctable) && defined?(DidYouMean::SpellChecker)
      include DidYouMean::Correctable # :nodoc:

      def corrections # :nodoc:
        @corrections ||= DidYouMean::SpellChecker.new(dictionary: controller.class.action_methods).correct(action)
      end
    end
  end

  # AbstractController::Base is a low-level API. Nobody should be
  # using it directly, and subclasses (like ActionController::Base) are
  # expected to provide their own +render+ method, since rendering means
  # different things depending on the context.
  class Base
    ##
    # Returns the body of the HTTP response sent by the controller.
    attr_internal :response_body

    ##
    # Returns the name of the action this controller is processing.
    attr_internal :action_name

    ##
    # Returns the formats that can be processed by the controller.
    attr_internal :formats

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

      def inherited(klass) # :nodoc:
        # Define the abstract ivar on subclasses so that we don't get
        # uninitialized ivar warnings
        unless klass.instance_variable_defined?(:@abstract)
          klass.instance_variable_set(:@abstract, false)
        end
        super
      end

      # A list of all internal methods for a controller. This finds the first
      # abstract superclass of a controller, and gets a list of all public
      # instance methods on that abstract class. Public instance methods of
      # a controller would normally be considered action methods, so methods
      # declared on abstract classes are being removed.
      # (<tt>ActionController::Metal</tt> and ActionController::Base are defined as abstract)
      def internal_methods
        controller = self

        controller = controller.superclass until controller.abstract?
        controller.public_instance_methods(true)
      end

      # A list of method names that should be considered actions. This
      # includes all public instance methods on a controller, less
      # any internal methods (see internal_methods), adding back in
      # any methods that are internal, but still exist on the class
      # itself.
      #
      # ==== Returns
      # * <tt>Set</tt> - A set of all methods that should be considered actions.
      def action_methods
        @action_methods ||= begin
          # All public instance methods of this class, including ancestors
          methods = (public_instance_methods(true) -
            # Except for public instance methods of Base and its ancestors
            internal_methods +
            # Be sure to include shadowed public instance methods of this class
            public_instance_methods(false))

          methods.map!(&:to_s)

          methods.to_set
        end
      end

      # action_methods are cached and there is sometimes a need to refresh
      # them. ::clear_action_methods! allows you to do that, so next time
      # you run action_methods, they will be recalculated.
      def clear_action_methods!
        @action_methods = nil
      end

      # Returns the full controller name, underscored, without the ending Controller.
      #
      #   class MyApp::MyPostsController < AbstractController::Base
      #
      #   end
      #
      #   MyApp::MyPostsController.controller_path # => "my_app/my_posts"
      #
      # ==== Returns
      # * <tt>String</tt>
      def controller_path
        @controller_path ||= name.delete_suffix("Controller").underscore unless anonymous?
      end

      # Refresh the cached action_methods when a new action_method is added.
      def method_added(name)
        super
        clear_action_methods!
      end
    end

    abstract!

    # Calls the action going through the entire action dispatch stack.
    #
    # The actual method that is called is determined by calling
    # #method_for_action. If no method can handle the action, then an
    # AbstractController::ActionNotFound error is raised.
    #
    # ==== Returns
    # * <tt>self</tt>
    def process(action, *args)
      @_action_name = action.to_s

      unless action_name = _find_action_name(@_action_name)
        raise ActionNotFound.new("The action '#{action}' could not be found for #{self.class.name}", self, action)
      end

      @_response_body = nil

      process_action(action_name, *args)
    end

    # Delegates to the class' ::controller_path
    def controller_path
      self.class.controller_path
    end

    # Delegates to the class' ::action_methods
    def action_methods
      self.class.action_methods
    end

    # Returns true if a method for the action is available and
    # can be dispatched, false otherwise.
    #
    # Notice that <tt>action_methods.include?("foo")</tt> may return
    # false and <tt>available_action?("foo")</tt> returns true because
    # this method considers actions that are also available
    # through other means, for example, implicit render ones.
    #
    # ==== Parameters
    # * <tt>action_name</tt> - The name of an action to be tested
    def available_action?(action_name)
      _find_action_name(action_name)
    end

    # Tests if a response body is set. Used to determine if the
    # +process_action+ callback needs to be terminated in
    # +AbstractController::Callbacks+.
    def performed?
      response_body
    end

    # Returns true if the given controller is capable of rendering
    # a path. A subclass of +AbstractController::Base+
    # may return false. An Email controller for example does not
    # support paths, only full URLs.
    def self.supports_path?
      true
    end

    def inspect # :nodoc:
      "#<#{self.class.name}:#{'%#016x' % (object_id << 1)}>"
    end

    private
      # Returns true if the name can be considered an action because
      # it has a method defined in the controller.
      #
      # ==== Parameters
      # * <tt>name</tt> - The name of an action to be tested
      def action_method?(name)
        self.class.action_methods.include?(name)
      end

      # Call the action. Override this in a subclass to modify the
      # behavior around processing an action. This, and not #process,
      # is the intended way to override action dispatching.
      #
      # Notice that the first argument is the method to be dispatched
      # which is *not* necessarily the same as the action name.
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
      def _handle_action_missing(*args)
        action_missing(@_action_name, *args)
      end

      # Takes an action name and returns the name of the method that will
      # handle the action.
      #
      # It checks if the action name is valid and returns false otherwise.
      #
      # See method_for_action for more information.
      #
      # ==== Parameters
      # * <tt>action_name</tt> - An action name to find a method name for
      #
      # ==== Returns
      # * <tt>string</tt> - The name of the method that handles the action
      # * false           - No valid method name could be found.
      # Raise +AbstractController::ActionNotFound+.
      def _find_action_name(action_name)
        _valid_action_name?(action_name) && method_for_action(action_name)
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
      # also provide a method (like +_handle_method_missing+) to handle
      # the case.
      #
      # If none of these conditions are true, and +method_for_action+
      # returns +nil+, an +AbstractController::ActionNotFound+ exception will be raised.
      #
      # ==== Parameters
      # * <tt>action_name</tt> - An action name to find a method name for
      #
      # ==== Returns
      # * <tt>string</tt> - The name of the method that handles the action
      # * <tt>nil</tt>    - No method name could be found.
      def method_for_action(action_name)
        if action_method?(action_name)
          action_name
        elsif respond_to?(:action_missing, true)
          "_handle_action_missing"
        end
      end

      # Checks if the action name is valid and returns false otherwise.
      def _valid_action_name?(action_name)
        !action_name.to_s.include? File::SEPARATOR
      end
  end
end
