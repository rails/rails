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
    module ClassMethods
      # Loads the <tt>file_name</tt> if reload_dependencies is true or requires if it's false.
      def require_dependency(file_name)
        reload_dependencies ? silence_warnings { load("#{file_name}.rb") } : require(file_name)
      end
      
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
            rescue LoadError
              raise LoadError, "Missing #{layer} #{dependency}.rb"
            end
          end
        end

        def inherited(child)
          inherited_without_model(child)
          return if child.controller_name == "application" # otherwise the ApplicationController in Rails will include itself
          begin
            child.model(Inflector.singularize(child.controller_name))
          rescue LoadError
            # No neither singular or plural model available for this controller
          end
        end        
    end
  end
end