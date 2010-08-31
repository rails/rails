require "action_dispatch/http/mime_type"
require 'active_support/core_ext/class/attribute'

# Legacy TemplateHandler stub
module ActionView
  class Template
    module Handlers #:nodoc:
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

    class Template::Handler
      class_attribute :default_format
      self.default_format = Mime::HTML

      def self.call(template)
        raise "Need to implement #{self.class.name}#call(template)"
      end

      def render(template, local_assigns)
        raise "Need to implement #{self.class.name}#render(template, local_assigns)"
      end
    end
  end

  TemplateHandlers = Template::Handlers
  TemplateHandler = Template::Handler
end
