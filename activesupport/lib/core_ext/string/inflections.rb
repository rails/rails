require File.dirname(__FILE__) + '/../../inflector'
module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Makes it possible to do "posts".singularize that returns "post" and "MegaCoolClass".underscore that returns "mega_cool_class".
      module Inflections
        def pluralize
          Inflector.pluralize(self)
        end

        def singularize
          Inflector.singularize(self)
        end

        def camelize
          Inflector.camelize(self)
        end

        def underscore
          Inflector.underscore(self)
        end

        def demodulize
          Inflector.demodulize(self)
        end

        def tableize
          Inflector.tableize(self)
        end

        def classify
          Inflector.classify(self)
        end
        
        def humanize
          Inflector.humanize(self)
        end

        def foreign_key(separate_class_name_and_id_with_underscore = true)
          Inflector.foreign_key(self, separate_class_name_and_id_with_underscore)
        end
      end
    end
  end
end
