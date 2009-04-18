module ActionController
  module Responder
    def self.included(klass)
      klass.extend ClassMethods
    end
    
    private
    def render_for_text(text) #:nodoc:
      @performed_render = true

      case text
      when Proc
        response.body = text
      when nil
        # Safari 2 doesn't pass response headers if the response is zero-length
        if response.body_parts.empty?
          response.body_parts << ' '
        end
      else
        response.body_parts << text
      end
    end
    
    # Returns a set of the methods defined as actions in your controller
    def action_methods
      self.class.action_methods
    end
    
    module ClassMethods
      def action_methods
        @action_methods ||=
          # All public instance methods of this class, including ancestors
          public_instance_methods(true).map { |m| m.to_s }.to_set -
          # Except for public instance methods of Base and its ancestors
          Base.public_instance_methods(true).map { |m| m.to_s } +
          # Be sure to include shadowed public instance methods of this class
          public_instance_methods(false).map { |m| m.to_s } -
          # And always exclude explicitly hidden actions
          hidden_actions
      end
    end
  end
end
