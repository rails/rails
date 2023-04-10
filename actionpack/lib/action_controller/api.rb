# frozen_string_literal: true

require "action_view"
require "action_controller"
require "action_controller/log_subscriber"

module ActionController
  # API Controller is a lightweight version of ActionController::Base,
  # created for applications that don't require all functionalities that a complete
  # \Rails controller provides, allowing you to create controllers with just the
  # features that you need for API only applications.
  #
  # An API Controller is different from a normal controller in the sense that
  # by default it doesn't include a number of features that are usually required
  # by browser access only: layouts and templates rendering,
  # flash, assets, and so on. This makes the entire controller stack thinner,
  # suitable for API applications. It doesn't mean you won't have such
  # features if you need them: they're all available for you to include in
  # your application, they're just not part of the default API controller stack.
  #
  # Normally, +ApplicationController+ is the only controller that inherits from
  # <tt>ActionController::API</tt>. All other controllers in turn inherit from
  # +ApplicationController+.
  #
  # A sample controller could look like this:
  #
  #   class PostsController < ApplicationController
  #     def index
  #       posts = Post.all
  #       render json: posts
  #     end
  #   end
  #
  # Request, response, and parameters objects all work the exact same way as
  # ActionController::Base.
  #
  # == Renders
  #
  # The default API Controller stack includes all renderers, which means you
  # can use <tt>render :json</tt> and siblings freely in your controllers. Keep
  # in mind that templates are not going to be rendered, so you need to ensure
  # your controller is calling either <tt>render</tt> or <tt>redirect_to</tt> in
  # all actions, otherwise it will return <tt>204 No Content</tt>.
  #
  #   def show
  #     post = Post.find(params[:id])
  #     render json: post
  #   end
  #
  # == Redirects
  #
  # Redirects are used to move from one action to another. You can use the
  # <tt>redirect_to</tt> method in your controllers in the same way as in
  # ActionController::Base. For example:
  #
  #   def create
  #     redirect_to root_url and return if not_authorized?
  #     # do stuff here
  #   end
  #
  # == Adding New Behavior
  #
  # In some scenarios you may want to add back some functionality provided by
  # ActionController::Base that is not present by default in
  # <tt>ActionController::API</tt>, for instance <tt>MimeResponds</tt>. This
  # module gives you the <tt>respond_to</tt> method. Adding it is quite simple,
  # you just need to include the module in a specific controller or in
  # +ApplicationController+ in case you want it available in your entire
  # application:
  #
  #   class ApplicationController < ActionController::API
  #     include ActionController::MimeResponds
  #   end
  #
  #   class PostsController < ApplicationController
  #     def index
  #       posts = Post.all
  #
  #       respond_to do |format|
  #         format.json { render json: posts }
  #         format.xml  { render xml: posts }
  #       end
  #     end
  #   end
  #
  # Make sure to check the modules included in ActionController::Base
  # if you want to use any other functionality that is not provided
  # by <tt>ActionController::API</tt> out of the box.
  class API < Metal
    abstract!

    # Shortcut helper that returns all the ActionController::API modules except
    # the ones passed as arguments:
    #
    #   class MyAPIBaseController < ActionController::Metal
    #     ActionController::API.without_modules(:UrlFor).each do |left|
    #       include left
    #     end
    #   end
    #
    # This gives better control over what you want to exclude and makes it easier
    # to create an API controller class, instead of listing the modules required
    # manually.
    def self.without_modules(*modules)
      modules = modules.map do |m|
        m.is_a?(Symbol) ? ActionController.const_get(m) : m
      end

      MODULES - modules
    end

    MODULES = [
      AbstractController::Rendering,

      UrlFor,
      Redirecting,
      ApiRendering,
      Renderers::All,
      ConditionalGet,
      BasicImplicitRender,
      StrongParameters,

      DataStreaming,
      DefaultHeaders,
      Logging,

      # Before callbacks should also be executed as early as possible, so
      # also include them at the bottom.
      AbstractController::Callbacks,

      # Append rescue at the bottom to wrap as much as possible.
      Rescue,

      # Add instrumentations hooks at the bottom, to ensure they instrument
      # all the methods properly.
      Instrumentation,

      # Params wrapper should come before instrumentation so they are
      # properly showed in logs
      ParamsWrapper
    ]

    MODULES.each do |mod|
      include mod
    end

    ActiveSupport.run_load_hooks(:action_controller_api, self)
    ActiveSupport.run_load_hooks(:action_controller, self)
  end
end
