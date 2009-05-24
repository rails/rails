require 'active_support/core_ext/module/attr_internal'

module AbstractController
  class Error < StandardError; end
  
  class DoubleRenderError < Error
    DEFAULT_MESSAGE = "Render and/or redirect were called multiple times in this action. Please note that you may only call render OR redirect, and at most once per action. Also note that neither redirect nor render terminate execution of the action, so if you want to exit an action after redirecting, you need to do something like \"redirect_to(...) and return\"."

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end  
  
  class Base
    
    attr_internal :response_body
    attr_internal :response_obj
    attr_internal :action_name

    class << self
      attr_reader :abstract    
      
      def abstract!
        @abstract = true
      end
      
      alias_method :abstract?, :abstract

      def inherited(klass)
        ::AbstractController::Base.subclasses << klass.to_s
        super
      end

      def subclasses
        @subclasses ||= []
      end
      
      def internal_methods
        controller = self
        controller = controller.superclass until controller.abstract?
        controller.public_instance_methods(true)
      end
      
      def process(action)
        new.process(action.to_s)
      end

      def hidden_actions
        []
      end
      
      def action_methods
        @action_methods ||=
          # All public instance methods of this class, including ancestors
          public_instance_methods(true).map { |m| m.to_s }.to_set -
          # Except for public instance methods of Base and its ancestors
          internal_methods.map { |m| m.to_s } +
          # Be sure to include shadowed public instance methods of this class
          public_instance_methods(false).map { |m| m.to_s } -
          # And always exclude explicitly hidden actions
          hidden_actions
      end
    end
    
    abstract!
    
    def initialize
      self.response_obj = {}
    end
    
    def process(action)
      @_action_name = action_name = action.to_s

      unless action_name = method_for_action(action_name)
        raise ActionNotFound, "The action '#{action}' could not be found"
      end

      process_action(action_name)
      self
    end
    
  private
  
    def action_methods
      self.class.action_methods
    end
  
    def action_method?(action)
      action_methods.include?(action)
    end
  
    # It is possible for respond_to?(action_name) to be false and
    # respond_to?(:action_missing) to be false if respond_to_action?
    # is overridden in a subclass. For instance, ActionController::Base
    # overrides it to include the case where a template matching the
    # action_name is found.
    def process_action(method_name)
      send(method_name)
    end

    def _handle_action_missing
      action_missing(@_action_name)
    end

    # Override this to change the conditions that will raise an
    # ActionNotFound error. If you accept a difference case,
    # you must handle it by also overriding process_action and
    # handling the case.
    def method_for_action(action_name)
      if action_method?(action_name) then action_name
      elsif respond_to?(:action_missing, true) then "_handle_action_missing"
      end
    end
  end
end