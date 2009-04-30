module AbstractController
  class Base
    
    attr_internal :response_body
    attr_internal :response_obj
    attr_internal :action_name
    
    def self.process(action)
      new.process(action)
    end
    
    def self.inherited(klass)
    end
    
    def initialize
      self.response_obj = {}
    end
    
    def process(action_name)
      unless respond_to_action?(action_name)
        raise ActionNotFound, "The action '#{action_name}' could not be found"
      end
      
      @_action_name = action_name
      process_action
      self.response_obj[:body] = self.response_body
      self
    end
    
  private
  
    # It is possible for respond_to?(action_name) to be false and
    # respond_to?(:action_missing) to be false if respond_to_action?
    # is overridden in a subclass. For instance, ActionController::Base
    # overrides it to include the case where a template matching the
    # action_name is found.
    def process_action
      if respond_to?(action_name) then send(action_name)
      elsif respond_to?(:action_missing, true) then send(:action_missing, action_name)
      end
    end
    
    # Override this to change the conditions that will raise an
    # ActionNotFound error. If you accept a difference case,
    # you must handle it by also overriding process_action and
    # handling the case.
    def respond_to_action?(action_name)
      respond_to?(action_name) || respond_to?(:action_missing, true)
    end
    
  end
end