unless Object.respond_to?(:require_dependency)
  Object.send(:define_method, :require_dependency) { |file_name| ActionController::Base.require_dependency(file_name) }
end

module ActionController #:nodoc:
  module Dependencies #:nodoc:
    def self.append_features(base)
      super

      base.class_eval do
        # When turned on (which is default), all dependencies are included using "load". This mean that any change is instant in cached
        # environments like mod_ruby or FastCGI. When set to false, "require" is used, which is faster but requires server restart to
        # be effective.
        @@reload_dependencies = true
        cattr_accessor :reload_dependencies
      end

      base.class_eval { class << self; alias_method :inherited_without_model, :inherited; end }

      base.extend(ClassMethods)
    end

    module ClassMethods
      # Loads the <tt>file_name</tt> if reload_dependencies is true or requires if it's false.
      def require_dependency(file_name)
        reload_dependencies ? silence_warnings { load("#{file_name}.rb") } : require(file_name)
      end
      
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

        def inherited(child)
          inherited_without_model(child)
          begin
            child.model(child.controller_name)
            child.model(Inflector.singularize(child.controller_name))
          rescue LoadError
            # No neither singular or plural model available for this controller
          end
        end        
    end
  end
end
