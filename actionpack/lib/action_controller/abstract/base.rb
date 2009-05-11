module AbstractController
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
    
    def process(action_name)
      unless respond_to_action?(action_name)
        raise ActionNotFound, "The action '#{action_name}' could not be found"
      end
      
      @_action_name = action_name
      process_action
      self
    end
    
  private
  
    def action_methods
      self.class.action_methods
    end
  
    # It is possible for respond_to?(action_name) to be false and
    # respond_to?(:action_missing) to be false if respond_to_action?
    # is overridden in a subclass. For instance, ActionController::Base
    # overrides it to include the case where a template matching the
    # action_name is found.
    def process_action
      if respond_to?(action_name) then send(action_name)
      elsif respond_to?(:action_missing, true) then action_missing(action_name)
      end
    end
    
    # Override this to change the conditions that will raise an
    # ActionNotFound error. If you accept a difference case,
    # you must handle it by also overriding process_action and
    # handling the case.
    def respond_to_action?(action_name)
      action_methods.include?(action_name) || respond_to?(:action_missing, true)
    end
  end
end