require 'abstract_controller/collector'

module ActionController #:nodoc:
  module MimeResponds
    extend ActiveSupport::Concern

    included do
      class_attribute :responder, :mimes_for_respond_to
      self.responder = ActionController::Responder
      clear_respond_to
    end

    module ClassMethods
      # Defines mime types that are rendered by default when invoking
      # <tt>respond_with</tt>.
      #
      #   respond_to :html, :xml, :json
      #
      # Specifies that all actions in the controller respond to requests
      # for <tt>:html</tt>, <tt>:xml</tt> and <tt>:json</tt>.
      #
      # To specify on per-action basis, use <tt>:only</tt> and
      # <tt>:except</tt> with an array of actions or a single action:
      #
      #   respond_to :html
      #   respond_to :xml, :json, :except => [ :edit ]
      #
      # This specifies that all actions respond to <tt>:html</tt>
      # and all actions except <tt>:edit</tt> respond to <tt>:xml</tt> and
      # <tt>:json</tt>.
      #
      #   respond_to :json, :only => :create
      #
      # This specifies that the <tt>:create</tt> action and no other responds
      # to <tt>:json</tt>.
      def respond_to(*mimes)
        options = mimes.extract_options!

        only_actions   = Array(options.delete(:only)).map(&:to_s)
        except_actions = Array(options.delete(:except)).map(&:to_s)

        new = mimes_for_respond_to.dup
        mimes.each do |mime|
          mime = mime.to_sym
          new[mime]          = {}
          new[mime][:only]   = only_actions   unless only_actions.empty?
          new[mime][:except] = except_actions unless except_actions.empty?
        end
        self.mimes_for_respond_to = new.freeze
      end

      # Clear all mime types in <tt>respond_to</tt>.
      #
      def clear_respond_to
        self.mimes_for_respond_to = Hash.new.freeze
      end
    end

    # Without web-service support, an action which collects the data for displaying a list of people
    # might look something like this:
    #
    #   def index
    #     @people = Person.all
    #   end
    #
    # Here's the same action, with web-service support baked in:
    #
    #   def index
    #     @people = Person.all
    #
    #     respond_to do |format|
    #       format.html
    #       format.xml { render :xml => @people }
    #     end
    #   end
    #
    # What that says is, "if the client wants HTML in response to this action, just respond as we
    # would have before, but if the client wants XML, return them the list of people in XML format."
    # (Rails determines the desired response format from the HTTP Accept header submitted by the client.)
    #
    # Supposing you have an action that adds a new person, optionally creating their company
    # (by name) if it does not already exist, without web-services, it might look like this:
    #
    #   def create
    #     @company = Company.find_or_create_by_name(params[:company][:name])
    #     @person  = @company.people.create(params[:person])
    #
    #     redirect_to(person_list_url)
    #   end
    #
    # Here's the same action, with web-service support baked in:
    #
    #   def create
    #     company  = params[:person].delete(:company)
    #     @company = Company.find_or_create_by_name(company[:name])
    #     @person  = @company.people.create(params[:person])
    #
    #     respond_to do |format|
    #       format.html { redirect_to(person_list_url) }
    #       format.js
    #       format.xml  { render :xml => @person.to_xml(:include => @company) }
    #     end
    #   end
    #
    # If the client wants HTML, we just redirect them back to the person list. If they want JavaScript,
    # then it is an Ajax request and we render the JavaScript template associated with this action.
    # Lastly, if the client wants XML, we render the created person as XML, but with a twist: we also
    # include the person's company in the rendered XML, so you get something like this:
    #
    #   <person>
    #     <id>...</id>
    #     ...
    #     <company>
    #       <id>...</id>
    #       <name>...</name>
    #       ...
    #     </company>
    #   </person>
    #
    # Note, however, the extra bit at the top of that action:
    #
    #   company  = params[:person].delete(:company)
    #   @company = Company.find_or_create_by_name(company[:name])
    #
    # This is because the incoming XML document (if a web-service request is in process) can only contain a
    # single root-node. So, we have to rearrange things so that the request looks like this (url-encoded):
    #
    #   person[name]=...&person[company][name]=...&...
    #
    # And, like this (xml-encoded):
    #
    #   <person>
    #     <name>...</name>
    #     <company>
    #       <name>...</name>
    #     </company>
    #   </person>
    #
    # In other words, we make the request so that it operates on a single entity's person. Then, in the action,
    # we extract the company data from the request, find or create the company, and then create the new person
    # with the remaining data.
    #
    # Note that you can define your own XML parameter parser which would allow you to describe multiple entities
    # in a single request (i.e., by wrapping them all in a single root node), but if you just go with the flow
    # and accept Rails' defaults, life will be much easier.
    #
    # If you need to use a MIME type which isn't supported by default, you can register your own handlers in
    # config/initializers/mime_types.rb as follows.
    #
    #   Mime::Type.register "image/jpg", :jpg
    #
    # Respond to also allows you to specify a common block for different formats by using any:
    #
    #   def index
    #     @people = Person.all
    #
    #     respond_to do |format|
    #       format.html
    #       format.any(:xml, :json) { render request.format.to_sym => @people }
    #     end
    #   end
    #
    # In the example above, if the format is xml, it will render:
    #
    #   render :xml => @people
    #
    # Or if the format is json:
    #
    #   render :json => @people
    #
    # Since this is a common pattern, you can use the class method respond_to
    # with the respond_with method to have the same results:
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
    # Be sure to check the documentation of +respond_with+ and
    # <tt>ActionController::MimeResponds.respond_to</tt> for more examples.
    def respond_to(*mimes, &block)
      raise ArgumentError, "respond_to takes either types or a block, never both" if mimes.any? && block_given?

      if collector = retrieve_collector_from_mimes(mimes, &block)
        response = collector.response
        response ? response.call : render({})
      end
    end

    # For a given controller action, respond_with generates an appropriate
    # response based on the mime-type requested by the client.
    #
    # If the method is called with just a resource, as in this example -
    #
    #   class PeopleController < ApplicationController
    #     respond_to :html, :xml, :json
    #
    #     def index
    #       @people = Person.all
    #       respond_with @people
    #     end
    #   end
    #
    # then the mime-type of the response is typically selected based on the
    # request's Accept header and the set of available formats declared
    # by previous calls to the controller's class method +respond_to+. Alternatively
    # the mime-type can be selected by explicitly setting <tt>request.format</tt> in
    # the controller.
    #
    # If an acceptable format is not identified, the application returns a
    # '406 - not acceptable' status. Otherwise, the default response is to render
    # a template named after the current action and the selected format,
    # e.g. <tt>index.html.erb</tt>. If no template is available, the behavior
    # depends on the selected format:
    #
    # * for an html response - if the request method is +get+, an exception
    #   is raised but for other requests such as +post+ the response
    #   depends on whether the resource has any validation errors (i.e.
    #   assuming that an attempt has been made to save the resource,
    #   e.g. by a +create+ action) -
    #   1. If there are no errors, i.e. the resource
    #      was saved successfully, the response +redirect+'s to the resource
    #      i.e. its +show+ action.
    #   2. If there are validation errors, the response
    #      renders a default action, which is <tt>:new</tt> for a
    #      +post+ request or <tt>:edit</tt> for +put+.
    #   Thus an example like this -
    #
    #     respond_to :html, :xml
    #
    #     def create
    #       @user = User.new(params[:user])
    #       flash[:notice] = 'User was successfully created.' if @user.save
    #       respond_with(@user)
    #     end
    #
    #   is equivalent, in the absence of <tt>create.html.erb</tt>, to -
    #
    #     def create
    #       @user = User.new(params[:user])
    #       respond_to do |format|
    #         if @user.save
    #           flash[:notice] = 'User was successfully created.'
    #           format.html { redirect_to(@user) }
    #           format.xml { render :xml => @user }
    #         else
    #           format.html { render :action => "new" }
    #           format.xml { render :xml => @user }
    #         end
    #       end
    #     end
    #
    # * for a javascript request - if the template isn't found, an exception is
    #   raised.
    # * for other requests - i.e. data formats such as xml, json, csv etc, if
    #   the resource passed to +respond_with+ responds to <code>to_<format></code>,
    #   the method attempts to render the resource in the requested format
    #   directly, e.g. for an xml request, the response is equivalent to calling 
    #   <code>render :xml => resource</code>.
    #
    # === Nested resources
    #
    # As outlined above, the +resources+ argument passed to +respond_with+
    # can play two roles. It can be used to generate the redirect url
    # for successful html requests (e.g. for +create+ actions when
    # no template exists), while for formats other than html and javascript
    # it is the object that gets rendered, by being converted directly to the
    # required format (again assuming no template exists).
    #
    # For redirecting successful html requests, +respond_with+ also supports
    # the use of nested resources, which are supplied in the same way as
    # in <code>form_for</code> and <code>polymorphic_url</code>. For example -
    #
    #   def create
    #     @project = Project.find(params[:project_id])
    #     @task = @project.comments.build(params[:task])
    #     flash[:notice] = 'Task was successfully created.' if @task.save
    #     respond_with(@project, @task)
    #   end
    #
    # This would cause +respond_with+ to redirect to <code>project_task_url</code>
    # instead of <code>task_url</code>. For request formats other than html or
    # javascript, if multiple resources are passed in this way, it is the last
    # one specified that is rendered.
    #
    # === Customizing response behavior
    #
    # Like +respond_to+, +respond_with+ may also be called with a block that
    # can be used to overwrite any of the default responses, e.g. -
    #
    #   def create
    #     @user = User.new(params[:user])
    #     flash[:notice] = "User was successfully created." if @user.save
    #
    #     respond_with(@user) do |format|
    #       format.html { render }
    #     end
    #   end
    #
    # The argument passed to the block is an ActionController::MimeResponds::Collector
    # object which stores the responses for the formats defined within the
    # block. Note that formats with responses defined explicitly in this way
    # do not have to first be declared using the class method +respond_to+.
    #
    # Also, a hash passed to +respond_with+ immediately after the specified
    # resource(s) is interpreted as a set of options relevant to all
    # formats. Any option accepted by +render+ can be used, e.g.
    #   respond_with @people, :status => 200
    # However, note that these options are ignored after an unsuccessful attempt
    # to save a resource, e.g. when automatically rendering <tt>:new</tt>
    # after a post request.
    #
    # Two additional options are relevant specifically to +respond_with+ -
    # 1. <tt>:location</tt> - overwrites the default redirect location used after
    #    a successful html +post+ request.
    # 2. <tt>:action</tt> - overwrites the default render action used after an
    #    unsuccessful html +post+ request.
    def respond_with(*resources, &block)
      raise "In order to use respond_with, first you need to declare the formats your " <<
            "controller responds to in the class level" if self.class.mimes_for_respond_to.empty?

      if collector = retrieve_collector_from_mimes(&block)
        options = resources.size == 1 ? {} : resources.extract_options!
        options[:default_response] = collector.response
        (options.delete(:responder) || self.class.responder).call(self, resources, options)
      end
    end

  protected

    # Collect mimes declared in the class method respond_to valid for the
    # current action.
    def collect_mimes_from_class_level #:nodoc:
      action = action_name.to_s

      self.class.mimes_for_respond_to.keys.select do |mime|
        config = self.class.mimes_for_respond_to[mime]

        if config[:except]
          !config[:except].include?(action)
        elsif config[:only]
          config[:only].include?(action)
        else
          true
        end
      end
    end

    # Returns a Collector object containing the appropriate mime-type response
    # for the current request, based on the available responses defined by a block.
    # In typical usage this is the block passed to +respond_with+ or +respond_to+.
    #
    # Sends :not_acceptable to the client and returns nil if no suitable format
    # is available.
    def retrieve_collector_from_mimes(mimes=nil, &block) #:nodoc:
      mimes ||= collect_mimes_from_class_level
      collector = Collector.new(mimes)
      block.call(collector) if block_given?
      format = collector.negotiate_format(request)

      if format
        self.content_type ||= format.to_s
        lookup_context.formats = [format.to_sym]
        lookup_context.rendered_format = lookup_context.formats.first
        collector
      else
        raise ActionController::UnknownFormat
      end
    end

    # A container for responses available from the current controller for
    # requests for different mime-types sent to a particular action.
    #
    # The public controller methods +respond_with+ and +respond_to+ may be called
    # with a block that is used to define responses to different mime-types, e.g.
    # for +respond_to+ :
    #
    #   respond_to do |format|
    #     format.html
    #     format.xml { render :xml => @people }
    #   end
    #
    # In this usage, the argument passed to the block (+format+ above) is an
    # instance of the ActionController::MimeResponds::Collector class. This
    # object serves as a container in which available responses can be stored by
    # calling any of the dynamically generated, mime-type-specific methods such
    # as +html+, +xml+ etc on the Collector. Each response is represented by a
    # corresponding block if present.
    #
    # A subsequent call to #negotiate_format(request) will enable the Collector
    # to determine which specific mime-type it should respond with for the current
    # request, with this response then being accessible by calling #response.
    class Collector
      include AbstractController::Collector
      attr_accessor :order, :format

      def initialize(mimes)
        @order, @responses = [], {}
        mimes.each { |mime| send(mime) }
      end

      def any(*args, &block)
        if args.any?
          args.each { |type| send(type, &block) }
        else
          custom(Mime::ALL, &block)
        end
      end
      alias :all :any

      def custom(mime_type, &block)
        mime_type = Mime::Type.lookup(mime_type.to_s) unless mime_type.is_a?(Mime::Type)
        @order << mime_type
        @responses[mime_type] ||= block
      end

      def response
        @responses[format] || @responses[Mime::ALL]
      end

      def negotiate_format(request)
        @format = request.negotiate_mime(order)
      end
    end
  end
end
