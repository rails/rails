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
  
    def process_action
      respond_to?(action_name) ? send(action_name) : send(:action_missing, action_name)
    end
    
    def respond_to_action?(action_name)
      respond_to?(action_name) || respond_to?(:action_missing, true)
    end
    
  end
end