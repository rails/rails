module ActionController #:nodoc:
  module Dependencies #:nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end

    module ClassMethods
      def model(*models)
        require_dependencies(:model, models)
        depend_on(:model, models)
      end

      def service(*services)
        require_dependencies(:service, services)
        depend_on(:service, services)
      end
      
      def observer(*observers)
        require_dependencies(:observer, observers)
        depend_on(:observer, observers)
        instantiate_observers(observers)
      end

      def dependencies_on(layer) # :nodoc:
        read_inheritable_attribute("#{layer}_dependencies")
      end
    
      def depend_on(layer, dependencies)
        write_inheritable_array("#{layer}_dependencies", dependencies)
      end

      private
        def instantiate_observers(observers)
          observers.flatten.each { |observer| Object.const_get(Inflector.classify(observer.to_s)).instance }
        end
        
        def require_dependencies(layer, dependencies)
          dependencies.flatten.each do |dependency|
            begin
              require_dependency(dependency.to_s)
            rescue LoadError
              raise LoadError, "Missing #{layer} #{dependency}.rb"
            end
          end
        end
    end
  end
end
