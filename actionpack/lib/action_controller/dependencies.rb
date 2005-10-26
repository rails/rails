module ActionController #:nodoc:
  module Dependencies #:nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end

    # Dependencies control what classes are needed for the controller to run its course. This is an alternative to doing explicit
    # +require+ statements that bring a number of benefits. It's more succinct, communicates what type of dependency we're talking about,
    # can trigger special behavior (as in the case of +observer+), and enables Rails to be clever about reloading in cached environments
    # like FCGI. Example:
    #
    #   class ApplicationController < ActionController::Base
    #     model    :account, :company, :person, :project, :category
    #     helper   :access_control
    #     service  :notifications, :billings
    #     observer :project_change_observer
    #   end
    #
    # Please note that a controller like ApplicationController will automatically attempt to require_dependency on a model of its 
    # singuralized name and a helper of its name. If nothing is found, no error is raised. This is especially useful for concrete 
    # controllers like PostController:
    #
    #   class PostController < ApplicationController
    #     # model  :post (already required)
    #     # helper :post (already required)
    #   end
    #
    # Also note, that if the models follow the pattern of just 1 class per file in the form of MyClass => my_class.rb, then these
    # classes don't have to be required as Active Support will auto-require them.
    module ClassMethods
      # Specifies a variable number of models that this controller depends on. Models are normally Active Record classes or a similar
      # backend for modelling entity classes.
      def model(*models)
        require_dependencies(:model, models)
        depend_on(:model, models)
      end

      # Specifies a variable number of services that this controller depends on. Services are normally singletons or factories, like
      # Action Mailer service or a Payment Gateway service.
      def service(*services)
        require_dependencies(:service, services)
        depend_on(:service, services)
      end
      
      # Specifies a variable number of observers that are to govern when this controller is handling actions. The observers will
      # automatically have .instance called on them to make them active on assignment.
      def observer(*observers)
        require_dependencies(:observer, observers)
        depend_on(:observer, observers)
        instantiate_observers(observers)
      end

      # Returns an array of symbols that specify the dependencies on a given layer. For the example at the top, calling
      # <tt>ApplicationController.dependencies_on(:model)</tt> would return <tt>[:account, :company, :person, :project, :category]</tt>
      def dependencies_on(layer)
        read_inheritable_attribute("#{layer}_dependencies")
      end
    
      def depend_on(layer, dependencies) #:nodoc:
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
            rescue LoadError => e
              raise LoadError.new("Missing #{layer} #{dependency}.rb").copy_blame!(e)
            rescue Object => exception
              exception.blame_file! "=> #{layer} #{dependency}.rb"
              raise
            end
          end
        end
    end
  end
end
