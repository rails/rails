module ActionController
  class AbstractBase < AbstractController::Base
    attr_internal :request, :response, :params

    def self.controller_name
      @controller_name ||= controller_path.split("/").last
    end

    def controller_name() self.class.controller_name end
    
    def self.controller_path
      @controller_path ||= self.name.sub(/Controller$/, '').underscore
    end
    
    def controller_path() self.class.controller_path end
      
    def self.action_methods
      @action_names ||= Set.new(self.public_instance_methods - self::CORE_METHODS)
    end
    
    def self.action_names() action_methods end
    
    def action_methods() self.class.action_names end
    def action_names() action_methods end
  end
end