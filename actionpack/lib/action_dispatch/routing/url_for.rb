module ActionDispatch
  module Routing
    # In <tt>config/routes.rb</tt> you define URL-to-controller mappings, but the reverse
    # is also possible: an URL can be generated from one of your routing definitions.
    # URL generation functionality is centralized in this module.
    #
    # See ActionDispatch::Routing for general information about routing and routes.rb.
    #
    # <b>Tip:</b> If you need to generate URLs from your models or some other place,
    # then ActionController::UrlFor is what you're looking for. Read on for
    # an introduction.
    #
    # == URL generation from parameters
    #
    # As you may know, some functions, such as ActionController::Base#url_for
    # and ActionView::Helpers::UrlHelper#link_to, can generate URLs given a set
    # of parameters. For example, you've probably had the chance to write code
    # like this in one of your views:
    #
    #   <%= link_to('Click here', :controller => 'users',
    #           :action => 'new', :message => 'Welcome!') %>
    #   # => "/users/new?message=Welcome%21"
    #
    # link_to, and all other functions that require URL generation functionality,
    # actually use ActionController::UrlFor under the hood. And in particular,
    # they use the ActionController::UrlFor#url_for method. One can generate
    # the same path as the above example by using the following code:
    #
    #   include UrlFor
    #   url_for(:controller => 'users',
    #           :action => 'new',
    #           :message => 'Welcome!',
    #           :only_path => true)
    #   # => "/users/new?message=Welcome%21"
    #
    # Notice the <tt>:only_path => true</tt> part. This is because UrlFor has no
    # information about the website hostname that your Rails app is serving. So if you
    # want to include the hostname as well, then you must also pass the <tt>:host</tt>
    # argument:
    #
    #   include UrlFor
    #   url_for(:controller => 'users',
    #           :action => 'new',
    #           :message => 'Welcome!',
    #           :host => 'www.example.com')        # Changed this.
    #   # => "http://www.example.com/users/new?message=Welcome%21"
    #
    # By default, all controllers and views have access to a special version of url_for,
    # that already knows what the current hostname is. So if you use url_for in your
    # controllers or your views, then you don't need to explicitly pass the <tt>:host</tt>
    # argument.
    #
    # For convenience reasons, mailers provide a shortcut for ActionController::UrlFor#url_for.
    # So within mailers, you only have to type 'url_for' instead of 'ActionController::UrlFor#url_for'
    # in full. However, mailers don't have hostname information, and what's why you'll still
    # have to specify the <tt>:host</tt> argument when generating URLs in mailers.
    #
    #
    # == URL generation for named routes
    #
    # UrlFor also allows one to access methods that have been auto-generated from
    # named routes. For example, suppose that you have a 'users' resource in your
    # <tt>config/routes.rb</tt>:
    #
    #   resources :users
    #
    # This generates, among other things, the method <tt>users_path</tt>. By default,
    # this method is accessible from your controllers, views and mailers. If you need
    # to access this auto-generated method from other places (such as a model), then
    # you can do that by including ActionController::UrlFor in your class:
    #
    #   class User < ActiveRecord::Base
    #     include Rails.application.routes.url_helpers
    #
    #     def base_uri
    #       user_path(self)
    #     end
    #   end
    #
    #   User.find(1).base_uri # => "/users/1"
    #
    module UrlFor
      extend ActiveSupport::Concern
      include PolymorphicRoutes

      included do
        # TODO: with_routing extends @controller with url_helpers, trickling down to including this module which overrides its default_url_options
        unless method_defined?(:default_url_options)
          # Including in a class uses an inheritable hash. Modules get a plain hash.
          if respond_to?(:class_attribute)
            class_attribute :default_url_options
          else
            mattr_accessor :default_url_options
            remove_method :default_url_options
          end

          self.default_url_options = {}
        end
      end

      def url_options
        default_url_options
      end

      # Generate a url based on the options provided, default_url_options and the
      # routes defined in routes.rb.  The following options are supported:
      #
      # * <tt>:only_path</tt> - If true, the relative url is returned. Defaults to +false+.
      # * <tt>:protocol</tt> - The protocol to connect to. Defaults to 'http'.
      # * <tt>:host</tt> - Specifies the host the link should be targeted at.
      #   If <tt>:only_path</tt> is false, this option must be
      #   provided either explicitly, or via +default_url_options+.
      # * <tt>:port</tt> - Optionally specify the port to connect to.
      # * <tt>:anchor</tt> - An anchor name to be appended to the path.
      # * <tt>:trailing_slash</tt> - If true, adds a trailing slash, as in "/archive/2009/"
      #
      # Any other key (<tt>:controller</tt>, <tt>:action</tt>, etc.) given to
      # +url_for+ is forwarded to the Routes module.
      #
      # Examples:
      #
      #    url_for :controller => 'tasks', :action => 'testing', :host=>'somehost.org', :port=>'8080'    # => 'http://somehost.org:8080/tasks/testing'
      #    url_for :controller => 'tasks', :action => 'testing', :host=>'somehost.org', :anchor => 'ok', :only_path => true    # => '/tasks/testing#ok'
      #    url_for :controller => 'tasks', :action => 'testing', :trailing_slash=>true  # => 'http://somehost.org/tasks/testing/'
      #    url_for :controller => 'tasks', :action => 'testing', :host=>'somehost.org', :number => '33'  # => 'http://somehost.org/tasks/testing?number=33'
      def url_for(options = nil)
        case options
        when String
          options
        when nil, Hash
          _routes.url_for((options || {}).reverse_merge!(url_options).symbolize_keys)
        else
          polymorphic_url(options)
        end
      end
    end
  end
end
