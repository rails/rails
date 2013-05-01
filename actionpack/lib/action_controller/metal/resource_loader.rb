module ActionController #:nodoc:

  #doc here
  module ResourceLoader
    extend ActiveSupport::Concern

    def load_resource(&block)
      LoadResourceCommand.new(self).instance_eval(&block)
    end

    class LoadResourceCommand
      
      def initialize(controller)
        @controller = controller
      end

      def before(&block)
        @controller.instance_eval(&block)
      end
      alias :after :before

      def for_action(*actions, &block)
        if actions.map(&:to_s).include?(@controller.action_name)
          @controller.instance_eval(&block)
        end
      end
      alias :for_actions :for_action

    end
  end



  # Responsible for exposing a resource to different mime requests,
  # usually depending on the HTTP verb. The responder is triggered when
  # <code>respond_with</code> is called. The simplest case to study is a GET request:
  #
  #   class PeopleController < ApplicationController
  #     respond_to :html, :xml, :json
  #
  #     def index
  #       @people = Person.all
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
  #         format.xml { render xml: @user, status: :created, location: @user }
  #       else
  #         format.html { render action: "new" }
  #         format.xml { render xml: @user.errors, status: :unprocessable_entity }
  #       end
  #     end
  #   end
  #
  # The same happens for PATCH/PUT and DELETE requests.
  #
  # === Nested resources
  #
  # You can supply nested resources as you do in <code>form_for</code> and <code>polymorphic_url</code>.
  # Consider the project has many tasks example. The create action for
  # TasksController would be like:
  #
  #   def create
  #     @project = Project.find(params[:project_id])
  #     @task = @project.tasks.build(params[:task])
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
  # <code>respond_with</code> also allows you to pass options that are forwarded
  # to the underlying render call. Those options are only applied for success
  # scenarios. For instance, you can do the following in the create method above:
  #
  #   def create
  #     @project = Project.find(params[:project_id])
  #     @task = @project.tasks.build(params[:task])
  #     flash[:notice] = 'Task was successfully created.' if @task.save
  #     respond_with(@project, @task, status: 201)
  #   end
  #
  # This will return status 201 if the task was saved successfully. If not,
  # it will simply ignore the given options and return status 422 and the
  # resource errors. To customize the failure scenario, you can pass a
  # a block to <code>respond_with</code>:
  #
  #   def create
  #     @project = Project.find(params[:project_id])
  #     @task = @project.tasks.build(params[:task])
  #     respond_with(@project, @task, status: 201) do |format|
  #       if @task.save
  #         flash[:notice] = 'Task was successfully created.'
  #       else
  #         format.html { render "some_special_template" }
  #       end
  #     end
  #   end
  #
  # Using <code>respond_with</code> with a block follows the same syntax as <code>respond_to</code>.
  
end
