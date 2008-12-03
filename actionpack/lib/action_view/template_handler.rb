# Legacy TemplateHandler stub
module ActionView
  module TemplateHandlers #:nodoc:
    module Compilable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def call(template)
          new.compile(template)
        end
      end

      def compile(template)
         raise "Need to implement #{self.class.name}#compile(template)"
       end
    end
  end

  class TemplateHandler
    def self.call(template)
      "#{name}.new(self).render(template, local_assigns)"
    end

    def initialize(view = nil)
      @view = view
    end

    def render(template, local_assigns)
      raise "Need to implement #{self.class.name}#render(template, local_assigns)"
    end
  end
end
