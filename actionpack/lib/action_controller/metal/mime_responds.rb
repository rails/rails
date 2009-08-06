module ActionController #:nodoc:
  module MimeResponds #:nodoc:
    extend ActiveSupport::Concern

    included do
      class_inheritable_reader :mimes_for_respond_to
      clear_respond_to
    end

    module ClassMethods
      # Defines mimes that are rendered by default when invoking respond_with.
      #
      # Examples:
      #
      #   respond_to :html, :xml, :json
      #
      # All actions on your controller will respond to :html, :xml and :json.
      #
      # But if you want to specify it based on your actions, you can use only and
      # except:
      #
      #   respond_to :html
      #   respond_to :xml, :json, :except => [ :edit ]
      #
      # The definition above explicits that all actions respond to :html. And all
      # actions except :edit respond to :xml and :json.
      #
      # You can specify also only parameters:
      #
      #   respond_to :rjs, :only => :create
      #
      def respond_to(*mimes)
        options = mimes.extract_options!

        only_actions   = Array(options.delete(:only))
        except_actions = Array(options.delete(:except))

        mimes.each do |mime|
          mime = mime.to_sym
          mimes_for_respond_to[mime]          = {}
          mimes_for_respond_to[mime][:only]   = only_actions   unless only_actions.empty?
          mimes_for_respond_to[mime][:except] = except_actions unless except_actions.empty?
        end
      end

      # Clear all mimes in respond_to.
      #
      def clear_respond_to
        write_inheritable_attribute(:mimes_for_respond_to, ActiveSupport::OrderedHash.new)
      end
    end

    # Without web-service support, an action which collects the data for displaying a list of people
    # might look something like this:
    #
    #   def index
    #     @people = Person.find(:all)
    #   end
    #
    # Here's the same action, with web-service support baked in:
    #
    #   def index
    #     @people = Person.find(:all)
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
    # If the client wants HTML, we just redirect them back to the person list. If they want Javascript
    # (format.js), then it is an RJS request and we render the RJS template associated with this action.
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
    # environment.rb as follows.
    #
    #   Mime::Type.register "image/jpg", :jpg
    #
    # Respond to also allows you to specify a common block for different formats by using any:
    #
    #   def index
    #     @people = Person.find(:all)
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
    #       @people = Person.find(:all)
    #       respond_with(@person)
    #     end
    #   end
    #
    # Be sure to check respond_with and respond_to documentation for more examples.
    #
    def respond_to(*mimes, &block)
      options = mimes.extract_options!
      raise ArgumentError, "respond_to takes either types or a block, never both" if mimes.any? && block_given?

      resource  = options.delete(:with)
      responder = Responder.new

      mimes = collect_mimes_from_class_level if mimes.empty?
      mimes.each { |mime| responder.send(mime) }
      block.call(responder) if block_given?

      if format = request.negotiate_mime(responder.order)
        respond_to_block_or_template_or_resource(format, resource,
          options, &responder.response_for(format))
      else
        head :not_acceptable
      end
    end

    # respond_with allows you to respond an action with a given resource. It
    # requires that you set your class with a :respond_to method with the
    # formats allowed:
    #
    #   class PeopleController < ApplicationController
    #     respond_to :html, :xml, :json
    #
    #     def index
    #       @people = Person.find(:all)
    #       respond_with(@person)
    #     end
    #   end
    #
    # When a request comes with format :xml, the respond_with will first search
    # for a template as person/index.xml, if the template is not available, it
    # will see if the given resource responds to :to_xml.
    #
    # If neither are available, it will raise an error.
    #
    # Extra parameters given to respond_with are used when :to_format is invoked.
    # This allows you to set status and location for several formats at the same
    # time. Consider this restful controller response on create for both xml
    # and json formats:
    #
    #   class PeopleController < ApplicationController
    #     respond_to :xml, :json
    #
    #     def create
    #       @person = Person.new(params[:person])
    #
    #       if @person.save
    #         respond_with(@person, :status => :ok, :location => person_url(@person))
    #       else
    #         respond_with(@person.errors, :status => :unprocessable_entity)
    #       end
    #     end
    #   end
    #
    # Finally, respond_with also accepts blocks, as in respond_to. Let's take
    # the same controller and create action above and add common html behavior:
    #
    #   class PeopleController < ApplicationController
    #     respond_to :html, :xml, :json
    #
    #     def create
    #       @person = Person.new(params[:person])
    #
    #       if @person.save
    #         options = { :status => :ok, :location => person_url(@person) }
    #
    #         respond_with(@person, options) do |format|
    #           format.html { redirect_to options[:location] }
    #         end
    #       else
    #         respond_with(@person.errors, :status => :unprocessable_entity) do
    #           format.html { render :action => :new }
    #         end
    #       end
    #     end
    #   end
    #
    def respond_with(resource, options={}, &block)
      respond_to(options.merge!(:with => resource), &block)
    end

  protected

    def respond_to_block_or_template_or_resource(format, resource, options)
      self.formats = [format.to_sym]
      return yield if block_given?

      begin
        default_render
      rescue ActionView::MissingTemplate => e
        if resource && resource.respond_to?(:"to_#{format.to_sym}")
          render options.merge(format.to_sym => resource)
        else
          raise e
        end
      end
    end

    # Collect mimes declared in the class method respond_to valid for the
    # current action.
    #
    def collect_mimes_from_class_level #:nodoc:
      action = action_name.to_sym

      mimes_for_respond_to.keys.select do |mime|
        config = mimes_for_respond_to[mime]

        if config[:except]
          !config[:except].include?(action)
        elsif config[:only]
          config[:only].include?(action)
        else
          true
        end
      end
    end

    class Responder #:nodoc:
      attr_accessor :order

      def initialize
        @order, @responses = [], {}
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
        mime_type = mime_type.is_a?(Mime::Type) ? mime_type : Mime::Type.lookup(mime_type.to_s)

        @order << mime_type
        @responses[mime_type] ||= block
      end

      def response_for(mime)
        @responses[mime] || @responses[Mime::ALL]
      end

      def self.generate_method_for_mime(mime)
        sym = mime.is_a?(Symbol) ? mime : mime.to_sym
        const = sym.to_s.upcase
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{sym}(&block)                # def html(&block)
            custom(Mime::#{const}, &block)  #   custom(Mime::HTML, &block)
          end                               # end
        RUBY
      end

      Mime::SET.each do |mime|
        generate_method_for_mime(mime)
      end

      def method_missing(symbol, &block)
        mime_constant = Mime.const_get(symbol.to_s.upcase)

        if Mime::SET.include?(mime_constant)
          self.class.generate_method_for_mime(mime_constant)
          send(symbol, &block)
        else
          super
        end
      end

    end
  end
end
