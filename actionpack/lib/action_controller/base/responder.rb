module ActionController
  module Responder
    def self.included(klass)
      klass.extend ClassMethods
    end
    
    private
    def render_for_text(text = nil, append_response = false) #:nodoc:
      @performed_render = true

      if append_response
        response.body ||= ''
        response.body << text.to_s
      else
        response.body = case text
          when Proc then text
          when nil  then " " # Safari doesn't pass the headers of the return if the response is zero length
          else           text.to_s
        end
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