module ActionController #:nodoc:
  module Authentication #:nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end

    # Authentication standardizes the need to protect certain actions unless a given condition is fulfilled. It doesn't address
    # _how_ someone becomes authorized, but only that if the condition isn't fulfilled a redirect to a given place will happen.
    #
    # The authentication model is setup up in two stages. One to configure the authentication, which is often done in the super-most
    # class (such as ApplicationController in Rails), and then the protection of actions in the individual controller subclasses:
    #
    #   class ApplicationController < ActionController::Base
    #     authentication :by => '@session[:authenticated]', :failure => { :controller => "login" }
    #   end
    #   
    #   class WeblogController < ApplicationController
    #     authenticates :edit, :update
    #
    #     def show()   render_text "I showed something"  end
    #     def index()  render_text "I indexed something" end
    #     def edit()   render_text "I edited something"  end
    #     def update() render_text "I updated something" end
    #     def login()  @session[:authenticated] = true; render_nothing end
    #   end
    # 
    # In the example above, the edit and update methods are protected by an authentication condition that requires 
    # <tt>@session[:authenticated]</tt> to be true. If that is not the case, the request is redirected to LoginController#index.
    # Note that the :by condition is enclosed in single quotes. This is because we want to defer evaluation of the condition until
    # we're at run time. Also note, that the :failure option uses the same format as Base#url_for and friends do to perform the redirect.
    module ClassMethods
      # Enables authentication for this class and all its subclasses.
      #
      # Options are:
      # * <tt>:by</tt> - the code fragment that will be evaluated on each request to determine whether the request is authenticated.
      # * <tt>:failure</tt> - redirection options following the format of Base#url_for.
      def authentication(options)
        options.assert_valid_keys([:by, :failure])
        class_eval <<-EOV
          protected          
            def actions_excepted_from_authentication
              self.class.read_inheritable_attribute("actions_excepted_from_authentication") || []
            end
          
            def actions_included_in_authentication
              actions = self.class.read_inheritable_attribute("actions_included_in_authentication")

              if actions == :all
                action_methods.collect { |action| action.intern }
              elsif actions.is_a?(Array)
                actions
              else
                []
              end
            end
          
            def action_needs_authentication?
              if actions_excepted_from_authentication.include?(action_name.intern)
                false
              elsif actions_included_in_authentication.include?(action_name.intern)
                true
              elsif actions_excepted_from_authentication.length > 0
                true
              else
                false
              end
            end
          
            def authenticate
              if !action_needs_authentication? || #{options[:by]}
                return true
              else
                redirect_to(#{options[:failure].inspect})
                return false
              end
            end
        EOV

        before_filter :authenticate
      end
      
      # Protects the actions specified behind the authentication condition.
      def authenticates(*actions)
        write_inheritable_array("actions_included_in_authentication", actions)
      end

      # Protects all the actions of this controller behind the authentication condition.
      def authenticates_all
        write_inheritable_attribute("actions_included_in_authentication", :all)
      end
      
      # Protects all the actions of this controller _except_ the listed behind the authentication condition.
      def authenticates_all_except(*actions)
        write_inheritable_array("actions_excepted_from_authentication", actions)
      end
    end
  end
end