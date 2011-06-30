require 'active_support/json'

module ActionController #:nodoc:
  # Responsible for exposing a resource to different mime requests,
  # usually depending on the HTTP verb. The responder is triggered when
  # <code>respond_with</code> is called. The simplest case to study is a GET request:
  #
  #   class PeopleController < ApplicationController
  #     respond_to :html, :xml, :json
  #
  #     def index
  #       @people = Person.find(:all)
  #       respond_with(@people)
  #     end
  #   end
  #
  # When a request comes in, for example for an XML response, three steps happen:
  #
  #   1) the responder searches for a template at people/index.xml;
  #
  #   2) if the template is not available, it will invoke <code>#to_xml</code> on the given resource;
  #
  #   3) if the responder does not <code>respond_to :to_xml</code>, call <code>#to_format</code> on it.
  #
  # === Builtin HTTP verb semantics
  #
  # The default \Rails responder holds semantics for each HTTP verb. Depending on the
  # content type, verb and the resource status, it will behave differently.
  #
  # Using \Rails default responder, a POST request for creating an object could
  # be written as:
  #
  #   def create
  #     @user = User.new(params[:user])
  #     flash[:notice] = 'User was successfully created.' if @user.save
  #     respond_with(@user)
  #   end
  #
  # Which is exactly the same as:
  #
  #   def create
  #     @user = User.new(params[:user])
  #
  #     respond_to do |format|
  #       if @user.save
  #         flash[:notice] = 'User was successfully created.'
  #         format.html { redirect_to(@user) }
  #         format.xml { render :xml => @user, :status => :created, :location => @user }
  #       else
  #         format.html { render :action => "new" }
  #         format.xml { render :xml => @user.errors, :status => :unprocessable_entity }
  #       end
  #     end
  #   end
  #
  # The same happens for PUT and DELETE requests.
  #
  # === Nested resources
  #
  # You can supply nested resources as you do in <code>form_for</code> and <code>polymorphic_url</code>.
  # Consider the project has many tasks example. The create action for
  # TasksController would be like:
  #
  #   def create
  #     @project = Project.find(params[:project_id])
  #     @task = @project.comments.build(params[:task])
  #     flash[:notice] = 'Task was successfully created.' if @task.save
  #     respond_with(@project, @task)
  #   end
  #
  # Giving several resources ensures that the responder will redirect to
  # <code>project_task_url</code> instead of <code>task_url</code>.
  #
  # Namespaced and singleton resources require a symbol to be given, as in
  # polymorphic urls. If a project has one manager which has many tasks, it
  # should be invoked as:
  #
  #   respond_with(@project, :manager, @task)
  #
  # Note that if you give an array, it will be treated as a collection,
  # so the following is not equivalent:
  #
  #   respond_with [@project, :manager, @task]
  #
  # === Custom options
  #
  # <code>respond_with</code> also allow you to pass options that are forwarded
  # to the underlying render call. Those options are only applied success
  # scenarios. For instance, you can do the following in the create method above:
  #
  #   def create
  #     @project = Project.find(params[:project_id])
  #     @task = @project.comments.build(params[:task])
  #     flash[:notice] = 'Task was successfully created.' if @task.save
  #     respond_with(@project, @task, :status => 201)
  #   end
  #
  # This will return status 201 if the task was saved with success. If not,
  # it will simply ignore the given options and return status 422 and the
  # resource errors. To customize the failure scenario, you can pass a
  # a block to <code>respond_with</code>:
  #
  #   def create
  #     @project = Project.find(params[:project_id])
  #     @task = @project.comments.build(params[:task])
  #     respond_with(@project, @task, :status => 201) do |format|
  #       if @task.save
  #         flash[:notice] = 'Task was successfully created.'
  #       else
  #         format.html { render "some_special_template" }
  #       end
  #     end
  #   end
  #
  # Using <code>respond_with</code> with a block follows the same syntax as <code>respond_to</code>.
  class Responder
    attr_reader :controller, :request, :format, :resource, :resources, :options

    ACTIONS_FOR_VERBS = {
      :post => :new,
      :put => :edit
    }

    def initialize(controller, resources, options={})
      @controller = controller
      @request = @controller.request
      @format = @controller.formats.first
      @resource = resources.last
      @resources = resources
      @options = options
      @action = options.delete(:action)
      @default_response = options.delete(:default_response)
    end

    delegate :head, :render, :redirect_to,   :to => :controller
    delegate :get?, :post?, :put?, :delete?, :to => :request

    # Undefine :to_json and :to_yaml since it's defined on Object
    undef_method(:to_json) if method_defined?(:to_json)
    undef_method(:to_yaml) if method_defined?(:to_yaml)

    # Initializes a new responder an invoke the proper format. If the format is
    # not defined, call to_format.
    #
    def self.call(*args)
      new(*args).respond
    end

    # Main entry point for responder responsible to dispatch to the proper format.
    #
    def respond
      method = "to_#{format}"
      respond_to?(method) ? send(method) : to_format
    end

    # HTML format does not render the resource, it always attempt to render a
    # template.
    #
    def to_html
      default_render
    rescue ActionView::MissingTemplate => e
      navigation_behavior(e)
    end

    # to_js simply tries to render a template. If no template is found, raises the error.
    def to_js
      default_render
    end

    # All other formats follow the procedure below. First we try to render a
    # template, if the template is not available, we verify if the resource
    # responds to :to_format and display it.
    #
    def to_format
      if get? || !has_errors?
        default_render
      else
        display_errors
      end
    rescue ActionView::MissingTemplate => e
      api_behavior(e)
    end

  protected

    # This is the common behavior for formats associated with browsing, like :html, :iphone and so forth.
    def navigation_behavior(error)
      if get?
        raise error
      elsif has_errors? && default_action
        render :action => default_action
      else
        redirect_to navigation_location
      end
    end

    # This is the common behavior for formats associated with APIs, such as :xml and :json.
    def api_behavior(error)
      raise error unless resourceful?

      if get?
        display resource
      elsif post?
        display resource, :status => :created, :location => api_location
      elsif has_empty_resource_definition?
        display empty_resource, :status => :ok
      else
        head :ok
      end
    end

    # Checks whether the resource responds to the current format or not.
    #
    def resourceful?
      resource.respond_to?("to_#{format}")
    end

    # Returns the resource location by retrieving it from the options or
    # returning the resources array.
    #
    def resource_location
      options[:location] || resources
    end
    alias :navigation_location :resource_location
    alias :api_location :resource_location

    # If a given response block was given, use it, otherwise call render on
    # controller.
    #
    def default_render
      @default_response.call(options)
    end

    # Display is just a shortcut to render a resource with the current format.
    #
    #   display @user, :status => :ok
    #
    # For XML requests it's equivalent to:
    #
    #   render :xml => @user, :status => :ok
    #
    # Options sent by the user are also used:
    #
    #   respond_with(@user, :status => :created)
    #   display(@user, :status => :ok)
    #
    # Results in:
    #
    #   render :xml => @user, :status => :created
    #
    def display(resource, given_options={})
      controller.render given_options.merge!(options).merge!(format => resource)
    end

    def display_errors
      controller.render format => resource.errors, :status => :unprocessable_entity
    end

    # Check whether the resource has errors.
    #
    def has_errors?
      resource.respond_to?(:errors) && !resource.errors.empty?
    end

    # By default, render the <code>:edit</code> action for HTML requests with failure, unless
    # the verb is POST.
    #
    def default_action
      @action ||= ACTIONS_FOR_VERBS[request.request_method_symbol]
    end

    # Check whether resource needs a specific definition of empty resource to be valid
    #
    def has_empty_resource_definition?
      respond_to?("empty_#{format}_resource")
    end

    # Delegate to proper empty resource method
    #
    def empty_resource
      send("empty_#{format}_resource")
    end

    # Return a valid empty JSON resource
    #
    def empty_json_resource
      "{}"
    end
  end
end
