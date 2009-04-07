module ActionController
  module HideActions
    setup do
      extlib_inheritable_accessor :hidden_actions
      self.hidden_actions ||= Set.new      
    end
    
    def action_methods() self.class.action_names end
    def action_names() action_methods end    
      
  private
  
    def respond_to_action?(action_name)
      !hidden_actions.include?(action_name) && (super || respond_to?(:method_missing))
    end
    
    module ClassMethods
      def hide_action(*args)
        args.each do |arg|
          self.hidden_actions << arg.to_s
        end
      end
      
      def action_methods
        @action_names ||= Set.new(super.reject {|name| self.hidden_actions.include?(name.to_s)})
      end

      def self.action_names() action_methods end
    end
  end
end