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
      @_action_name = action_name
      process_action
      self.response_obj[:body] = self.response_body
      self
    end
    
    def process_action
      send(action_name)
    end
    
  end
end