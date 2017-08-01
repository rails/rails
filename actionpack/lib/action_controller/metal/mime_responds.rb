# frozen_string_literal: true

require "abstract_controller/collector"

module ActionController #:nodoc:
  module MimeResponds
    # Without web-service support, an action which collects the data for displaying a list of people
    # might look something like this:
    #
    #   def index
    #     @people = Person.all
    #   end
    #
    # That action implicitly responds to all formats, but formats can also be whitelisted:
    #
    #   def index
    #     @people = Person.all
    #     respond_to :html, :js
    #   end
    #
    # Here's the same action, with web-service support baked in:
    #
    #   def index
    #     @people = Person.all
    #
    #     respond_to do |format|
    #       format.html
    #       format.js
    #       format.xml { render xml: @people }
    #     end
    #   end
    #
    # What that says is, "if the client wants HTML or JS in response to this action, just respond as we
    # would have before, but if the client wants XML, return them the list of people in XML format."
    # (Rails determines the desired response format from the HTTP Accept header submitted by the client.)
    #
    # Supposing you have an action that adds a new person, optionally creating their company
    # (by name) if it does not already exist, without web-services, it might look like this:
    #
    #   def create
    #     @company = Company.find_or_create_by(name: params[:company][:name])
    #     @person  = @company.people.create(params[:person])
    #
    #     redirect_to(person_list_url)
    #   end
    #
    # Here's the same action, with web-service support baked in:
    #
    #   def create
    #     company  = params[:person].delete(:company)
    #     @company = Company.find_or_create_by(name: company[:name])
    #     @person  = @company.people.create(params[:person])
    #
    #     respond_to do |format|
    #       format.html { redirect_to(person_list_url) }
    #       format.js
    #       format.xml  { render xml: @person.to_xml(include: @company) }
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
    #   @company = Company.find_or_create_by(name: company[:name])
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
    # +config/initializers/mime_types.rb+ as follows.
    #
    #   Mime::Type.register "image/jpg", :jpg
    #
    # Respond to also allows you to specify a common block for different formats by using +any+:
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
    #   render xml: @people
    #
    # Or if the format is json:
    #
    #   render json: @people
    #
    # Formats can have different variants.
    #
    # The request variant is a specialization of the request format, like <tt>:tablet</tt>,
    # <tt>:phone</tt>, or <tt>:desktop</tt>.
    #
    # We often want to render different html/json/xml templates for phones,
    # tablets, and desktop browsers. Variants make it easy.
    #
    # You can set the variant in a +before_action+:
    #
    #   request.variant = :tablet if request.user_agent =~ /iPad/
    #
    # Respond to variants in the action just like you respond to formats:
    #
    #   respond_to do |format|
    #     format.html do |variant|
    #       variant.tablet # renders app/views/projects/show.html+tablet.erb
    #       variant.phone { extra_setup; render ... }
    #       variant.none  { special_setup } # executed only if there is no variant set
    #     end
    #   end
    #
    # Provide separate templates for each format and variant:
    #
    #   app/views/projects/show.html.erb
    #   app/views/projects/show.html+tablet.erb
    #   app/views/projects/show.html+phone.erb
    #
    # When you're not sharing any code within the format, you can simplify defining variants
    # using the inline syntax:
    #
    #   respond_to do |format|
    #     format.js         { render "trash" }
    #     format.html.phone { redirect_to progress_path }
    #     format.html.none  { render "trash" }
    #   end
    #
    # Variants also support common +any+/+all+ block that formats have.
    #
    # It works for both inline:
    #
    #   respond_to do |format|
    #     format.html.any   { render html: "any"   }
    #     format.html.phone { render html: "phone" }
    #   end
    #
    # and block syntax:
    #
    #   respond_to do |format|
    #     format.html do |variant|
    #       variant.any(:tablet, :phablet){ render html: "any" }
    #       variant.phone { render html: "phone" }
    #     end
    #   end
    #
    # You can also set an array of variants:
    #
    #   request.variant = [:tablet, :phone]
    #
    # This will work similarly to formats and MIME types negotiation. If there
    # is no +:tablet+ variant declared, the +:phone+ variant will be used:
    #
    #   respond_to do |format|
    #     format.html.none
    #     format.html.phone # this gets rendered
    #   end
    def respond_to(*mimes)
      raise ArgumentError, "respond_to takes either types or a block, never both" if mimes.any? && block_given?

      collector = Collector.new(mimes, request.variant)
      yield collector if block_given?

      if format = collector.negotiate_format(request)
        _process_format(format)
        _set_rendered_content_type format
        response = collector.response
        response.call if response
      else
        raise ActionController::UnknownFormat
      end
    end

    # A container for responses available from the current controller for
    # requests for different mime-types sent to a particular action.
    #
    # The public controller methods +respond_to+ may be called with a block
    # that is used to define responses to different mime-types, e.g.
    # for +respond_to+ :
    #
    #   respond_to do |format|
    #     format.html
    #     format.xml { render xml: @people }
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
      attr_accessor :format

      def initialize(mimes, variant = nil)
        @responses = {}
        @variant = variant

        mimes.each { |mime| @responses[Mime[mime]] = nil }
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
        @responses[mime_type] ||= if block_given?
          block
        else
          VariantCollector.new(@variant)
        end
      end

      def response
        response = @responses.fetch(format, @responses[Mime::ALL])
        if response.is_a?(VariantCollector) # `format.html.phone` - variant inline syntax
          response.variant
        elsif response.nil? || response.arity == 0 # `format.html` - just a format, call its block
          response
        else # `format.html{ |variant| variant.phone }` - variant block syntax
          variant_collector = VariantCollector.new(@variant)
          response.call(variant_collector) # call format block with variants collector
          variant_collector.variant
        end
      end

      def negotiate_format(request)
        @format = request.negotiate_mime(@responses.keys)
      end

      class VariantCollector #:nodoc:
        def initialize(variant = nil)
          @variant = variant
          @variants = {}
        end

        def any(*args, &block)
          if block_given?
            if args.any? && args.none? { |a| a == @variant }
              args.each { |v| @variants[v] = block }
            else
              @variants[:any] = block
            end
          end
        end
        alias :all :any

        def method_missing(name, *args, &block)
          @variants[name] = block if block_given?
        end

        def variant
          if @variant.empty?
            @variants[:none] || @variants[:any]
          else
            @variants[variant_key]
          end
        end

        private
          def variant_key
            @variant.find { |variant| @variants.key?(variant) } || :any
          end
      end
    end
  end
end
