module ActionController #:nodoc:
  module Dependencies #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Deprecated module. The responsibility of loading dependencies belong with Active Support now.
    module ClassMethods #:nodoc:
      # Specifies a variable number of models that this controller depends on. Models are normally Active Record classes or a similar
      # backend for modelling entity classes.
      def model(*models)
        require_dependencies(:model, models)
        depend_on(:model, models)
      end
      deprecate :model

      # Specifies a variable number of services that this controller depends on. Services are normally singletons or factories, like
      # Action Mailer service or a Payment Gateway service.
      def service(*services)
        require_dependencies(:service, services)
        depend_on(:service, services)
      end
      deprecate :service
      
      # Specifies a variable number of observers that are to govern when this controller is handling actions. The observers will
      # automatically have .instance called on them to make them active on assignment.
      def observer(*observers)
        require_dependencies(:observer, observers)
        depend_on(:observer, observers)
        instantiate_observers(observers)
      end
      deprecate :observer

      # Returns an array of symbols that specify the dependencies on a given layer. For the example at the top, calling
      # <tt>ApplicationController.dependencies_on(:model)</tt> would return <tt>[:account, :company, :person, :project, :category]</tt>
      def dependencies_on(layer)
        read_inheritable_attribute("#{layer}_dependencies")
      end
      deprecate :dependencies_on

      def depend_on(layer, dependencies) #:nodoc:
        write_inheritable_array("#{layer}_dependencies", dependencies)
      end
      deprecate :depend_on

      private
        def instantiate_observers(observers)
          observers.flatten.each { |observer| Object.const_get(Inflector.classify(observer.to_s)).instance }
        end
        
        def require_dependencies(layer, dependencies)
          dependencies.flatten.each do |dependency|
            begin
              require_dependency(dependency.to_s)
            rescue LoadError => e
              raise LoadError.new("Missing #{layer} #{dependency}.rb").copy_blame!(e)
            rescue Exception => exception  # error from loaded file
              exception.blame_file! "=> #{layer} #{dependency}.rb"
              raise
            end
          end
        end
    end
  end
end
