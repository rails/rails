require 'abstract_controller/collector'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object/inclusion'

module ActionController #:nodoc:
  module MimeResponds
    extend ActiveSupport::Concern

    include ActionController::ImplicitRender

    included do
      class_attribute :responder, :mimes_for_respond_to
      self.responder = ActionController::Responder
      clear_respond_to
    end

    module ClassMethods
      # Defines mime types that are rendered by default when invoking
      # <tt>respond_with</tt>.
      #
      # Examples:
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
        self.mimes_for_respond_to = ActiveSupport::OrderedHash.new.freeze
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
    #       format.xml { render :xml => @people.to_xml }
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
    # Be sure to check respond_with and respond_to documentation for more examples.
    #
    def respond_to(*mimes, &block)
      raise ArgumentError, "respond_to takes either types or a block, never both" if mimes.any? && block_given?

      if collector = retrieve_collector_from_mimes(mimes, &block)
        response = collector.response
        response ? response.call : default_render({})
      end
    end

    # respond_with wraps a resource around a responder for default representation.
    # First it invokes respond_to, if a response cannot be found (ie. no block
    # for the request was given and template was not available), it instantiates
    # an ActionController::Responder with the controller and resource.
    #
    # ==== Example
    #
    #   def index
    #     @users = User.all
    #     respond_with(@users)
    #   end
    #
    # It also accepts a block to be given. It's used to overwrite a default
    # response:
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
    # All options given to respond_with are sent to the underlying responder,
    # except for the option :responder itself. Since the responder interface
    # is quite simple (it just needs to respond to call), you can even give
    # a proc to it.
    #
    # In order to use respond_with, first you need to declare the formats your
    # controller responds to in the class level with a call to <tt>respond_to</tt>.
    #
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
    #
    def collect_mimes_from_class_level #:nodoc:
      action = action_name.to_s

      self.class.mimes_for_respond_to.keys.select do |mime|
        config = self.class.mimes_for_respond_to[mime]

        if config[:except]
          !action.in?(config[:except])
        elsif config[:only]
          action.in?(config[:only])
        else
          true
        end
      end
    end

    # Collects mimes and return the response for the negotiated format. Returns
    # nil if :not_acceptable was sent to the client.
    #
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
        head :not_acceptable
        nil
      end
    end

    class Collector #:nodoc:
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
