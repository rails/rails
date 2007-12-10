require 'active_resource/connection'
require 'cgi'
require 'set'

module ActiveResource
  # ActiveResource::Base is the main class for mapping RESTful resources as models in a Rails application.
  #
  # For an outline of what Active Resource is capable of, see link:files/README.html.
  #
  # == Automated mapping
  #
  # Active Resource objects represent your RESTful resources as manipulatable Ruby objects.  To map resources
  # to Ruby objects, Active Resource only needs a class name that corresponds to the resource name (e.g., the class
  # Person maps to the resources people, very similarly to Active Record) and a +site+ value, which holds the
  # URI of the resources.
  # 
  #     class Person < ActiveResource::Base
  #       self.site = "http://api.people.com:3000/"
  #     end
  # 
  # Now the Person class is mapped to RESTful resources located at <tt>http://api.people.com:3000/people/</tt>, and
  # you can now use Active Resource's lifecycles methods to manipulate resources.  
  # 
  # == Lifecycle methods
  #
  # Active Resource exposes methods for creating, finding, updating, and deleting resources
  # from REST web services.
  # 
  #   ryan = Person.new(:first => 'Ryan', :last => 'Daigle')
  #   ryan.save  #=> true
  #   ryan.id  #=> 2
  #   Person.exists?(ryan.id)  #=> true
  #   ryan.exists?  #=> true
  # 
  #   ryan = Person.find(1)
  #   # => Resource holding our newly create Person object
  # 
  #   ryan.first = 'Rizzle'
  #   ryan.save  #=> true
  # 
  #   ryan.destroy  #=> true
  #
  # As you can see, these are very similar to Active Record's lifecycle methods for database records.
  # You can read more about each of these methods in their respective documentation.
  # 
  # === Custom REST methods
  #
  # Since simple CRUD/lifecycle methods can't accomplish every task, Active Resource also supports
  # defining your own custom REST methods.
  # 
  #   Person.new(:name => 'Ryan).post(:register)
  #   # => { :id => 1, :name => 'Ryan', :position => 'Clerk' }
  #
  #   Person.find(1).put(:promote, :position => 'Manager')
  #   # => { :id => 1, :name => 'Ryan', :position => 'Manager' }
  # 
  # For more information on creating and using custom REST methods, see the 
  # ActiveResource::CustomMethods documentation.
  #
  # == Validations
  #
  # You can validate resources client side by overriding validation methods in the base class.
  # 
  #     class Person < ActiveResource::Base
  #        self.site = "http://api.people.com:3000/"
  #        protected
  #          def validate
  #            errors.add("last", "has invalid characters") unless last =~ /[a-zA-Z]*/
  #          end
  #     end
  # 
  # See the ActiveResource::Validations documentation for more information.
  #
  # == Authentication
  # 
  # Many REST APIs will require authentication, usually in the form of basic
  # HTTP authentication.  Authentication can be specified by putting the credentials
  # in the +site+ variable of the Active Resource class you need to authenticate.
  # 
  #   class Person < ActiveResource::Base
  #     self.site = "http://ryan:password@api.people.com:3000/"
  #   end
  # 
  # For obvious security reasons, it is probably best if such services are available 
  # over HTTPS.
  # 
  # == Errors & Validation
  #
  # Error handling and validation is handled in much the same manner as you're used to seeing in
  # Active Record.  Both the response code in the Http response and the body of the response are used to
  # indicate that an error occurred.
  # 
  # === Resource errors
  # 
  # When a get is requested for a resource that does not exist, the HTTP +404+ (Resource Not Found)
  # response code will be returned from the server which will raise an ActiveResource::ResourceNotFound
  # exception.
  # 
  #   # GET http://api.people.com:3000/people/999.xml
  #   ryan = Person.find(999) # => Raises ActiveResource::ResourceNotFound
  #   # => Response = 404
  # 
  # +404+ is just one of the HTTP error response codes that ActiveResource will handle with its own exception. The 
  # following HTTP response codes will also result in these exceptions:
  # 
  # 200 - 399:: Valid response, no exception
  # 404:: ActiveResource::ResourceNotFound
  # 409:: ActiveResource::ResourceConflict
  # 422:: ActiveResource::ResourceInvalid (rescued by save as validation errors)
  # 401 - 499:: ActiveResource::ClientError
  # 500 - 599:: ActiveResource::ServerError
  #
  # These custom exceptions allow you to deal with resource errors more naturally and with more precision
  # rather than returning a general HTTP error.  For example:
  #
  #   begin
  #     ryan = Person.find(my_id)
  #   rescue ActiveResource::ResourceNotFound
  #     redirect_to :action => 'not_found'
  #   rescue ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid
  #     redirect_to :action => 'new'
  #   end
  #
  # === Validation errors
  # 
  # Active Resource supports validations on resources and will return errors if any these validations fail
  # (e.g., "First name can not be blank" and so on).  These types of errors are denoted in the response by 
  # a response code of +422+ and an XML representation of the validation errors.  The save operation will 
  # then fail (with a +false+ return value) and the validation errors can be accessed on the resource in question.
  # 
  #   ryan = Person.find(1)
  #   ryan.first #=> ''
  #   ryan.save  #=> false
  #
  #   # When 
  #   # PUT http://api.people.com:3000/people/1.xml
  #   # is requested with invalid values, the response is:
  #   #
  #   # Response (422):
  #   # <errors type="array"><error>First cannot be empty</error></errors>
  #   #
  #
  #   ryan.errors.invalid?(:first)  #=> true
  #   ryan.errors.full_messages  #=> ['First cannot be empty']
  # 
  # Learn more about Active Resource's validation features in the ActiveResource::Validations documentation.
  #
  class Base
    # The logger for diagnosing and tracing Active Resource calls.
    cattr_accessor :logger

    class << self
      # Gets the URI of the REST resources to map for this class.  The site variable is required 
      # ActiveResource's mapping to work.
      def site
        if defined?(@site)
          @site
        elsif superclass != Object && superclass.site
          superclass.site.dup.freeze
        end
      end

      # Sets the URI of the REST resources to map for this class to the value in the +site+ argument.
      # The site variable is required ActiveResource's mapping to work.
      def site=(site)
        @connection = nil
        @site = site.nil? ? nil : create_site_uri_from(site)
      end

      # Sets the format that attributes are sent and received in from a mime type reference. Example:
      #
      #   Person.format = :json
      #   Person.find(1) # => GET /people/1.json
      #
      #   Person.format = ActiveResource::Formats::XmlFormat
      #   Person.find(1) # => GET /people/1.xml
      #
      # Default format is :xml.
      def format=(mime_type_reference_or_format)
        format = mime_type_reference_or_format.is_a?(Symbol) ? 
          ActiveResource::Formats[mime_type_reference_or_format] : mime_type_reference_or_format

        write_inheritable_attribute("format", format)
        connection.format = format
      end
      
      # Returns the current format, default is ActiveResource::Formats::XmlFormat
      def format # :nodoc:
        read_inheritable_attribute("format") || ActiveResource::Formats[:xml]
      end

      # An instance of ActiveResource::Connection that is the base connection to the remote service.
      # The +refresh+ parameter toggles whether or not the connection is refreshed at every request
      # or not (defaults to +false+).
      def connection(refresh = false)
        if defined?(@connection) || superclass == Object
          @connection = Connection.new(site, format) if refresh || @connection.nil?
          @connection
        else
          superclass.connection
        end
      end

      def headers
        @headers ||= {}
      end

      # Do not include any modules in the default element name. This makes it easier to seclude ARes objects
      # in a separate namespace without having to set element_name repeatedly.
      attr_accessor_with_default(:element_name)    { to_s.split("::").last.underscore } #:nodoc:

      attr_accessor_with_default(:collection_name) { element_name.pluralize } #:nodoc:
      attr_accessor_with_default(:primary_key, 'id') #:nodoc:
      
      # Gets the prefix for a resource's nested URL (e.g., <tt>prefix/collectionname/1.xml</tt>)
      # This method is regenerated at runtime based on what the prefix is set to.
      def prefix(options={})
        default = site.path
        default << '/' unless default[-1..-1] == '/'
        # generate the actual method based on the current site path
        self.prefix = default
        prefix(options)
      end

      # An attribute reader for the source string for the resource path prefix.  This
      # method is regenerated at runtime based on what the prefix is set to.
      def prefix_source
        prefix # generate #prefix and #prefix_source methods first
        prefix_source
      end

      # Sets the prefix for a resource's nested URL (e.g., <tt>prefix/collectionname/1.xml</tt>).
      # Default value is <tt>site.path</tt>.
      def prefix=(value = '/')
        # Replace :placeholders with '#{embedded options[:lookups]}'
        prefix_call = value.gsub(/:\w+/) { |key| "\#{options[#{key}]}" }

        # Redefine the new methods.
        code = <<-end_code
          def prefix_source() "#{value}" end
          def prefix(options={}) "#{prefix_call}" end
        end_code
        silence_warnings { instance_eval code, __FILE__, __LINE__ }
      rescue
        logger.error "Couldn't set prefix: #{$!}\n  #{code}"
        raise
      end

      alias_method :set_prefix, :prefix=  #:nodoc:

      alias_method :set_element_name, :element_name=  #:nodoc:
      alias_method :set_collection_name, :collection_name=  #:nodoc:

      # Gets the element path for the given ID in +id+.  If the +query_options+ parameter is omitted, Rails
      # will split from the prefix options.
      #
      # ==== Options
      # +prefix_options+:: A hash to add a prefix to the request for nested URL's (e.g., <tt>:account_id => 19</tt>
      #                    would yield a URL like <tt>/accounts/19/purchases.xml</tt>).
      # +query_options+:: A hash to add items to the query string for the request.
      #
      # ==== Examples
      #   Post.element_path(1) 
      #   # => /posts/1.xml
      #
      #   Comment.element_path(1, :post_id => 5) 
      #   # => /posts/5/comments/1.xml
      #
      #   Comment.element_path(1, :post_id => 5, :active => 1) 
      #   # => /posts/5/comments/1.xml?active=1
      #
      #   Comment.element_path(1, {:post_id => 5}, {:active => 1}) 
      #   # => /posts/5/comments/1.xml?active=1
      #
      def element_path(id, prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}/#{id}.#{format.extension}#{query_string(query_options)}"
      end

      # Gets the collection path for the REST resources.  If the +query_options+ parameter is omitted, Rails
      # will split from the +prefix_options+.
      #
      # ==== Options
      # +prefix_options+:: A hash to add a prefix to the request for nested URL's (e.g., <tt>:account_id => 19</tt>
      #                    would yield a URL like <tt>/accounts/19/purchases.xml</tt>).
      # +query_options+:: A hash to add items to the query string for the request.
      #
      # ==== Examples
      #   Post.collection_path
      #   # => /posts.xml
      #
      #   Comment.collection_path(:post_id => 5) 
      #   # => /posts/5/comments.xml
      #
      #   Comment.collection_path(:post_id => 5, :active => 1) 
      #   # => /posts/5/comments.xml?active=1
      #
      #   Comment.collection_path({:post_id => 5}, {:active => 1}) 
      #   # => /posts/5/comments.xml?active=1
      #
      def collection_path(prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}.#{format.extension}#{query_string(query_options)}"
      end

      alias_method :set_primary_key, :primary_key=  #:nodoc:

      # Create a new resource instance and request to the remote service
      # that it be saved, making it equivalent to the following simultaneous calls:
      #
      #   ryan = Person.new(:first => 'ryan')
      #   ryan.save
      #
      # The newly created resource is returned.  If a failure has occurred an
      # exception will be raised (see save).  If the resource is invalid and
      # has not been saved then valid? will return <tt>false</tt>,
      # while new? will still return <tt>true</tt>.
      #
      # ==== Examples
      #   Person.create(:name => 'Jeremy', :email => 'myname@nospam.com', :enabled => true)
      #   my_person = Person.find(:first)
      #   my_person.email
      #   # => myname@nospam.com
      #
      #   dhh = Person.create(:name => 'David', :email => 'dhh@nospam.com', :enabled => true)
      #   dhh.valid?
      #   # => true
      #   dhh.new?
      #   # => false
      #
      #   # We'll assume that there's a validation that requires the name attribute
      #   that_guy = Person.create(:name => '', :email => 'thatguy@nospam.com', :enabled => true)
      #   that_guy.valid?
      #   # => false
      #   that_guy.new?
      #   # => true
      #
      def create(attributes = {})
        returning(self.new(attributes)) { |res| res.save }        
      end

      # Core method for finding resources.  Used similarly to Active Record's find method.
      #
      # ==== Arguments
      # The first argument is considered to be the scope of the query.  That is, how many 
      # resources are returned from the request.  It can be one of the following.
      #
      # +:one+:: Returns a single resource.
      # +:first+:: Returns the first resource found.
      # +:all+:: Returns every resource that matches the request.
      # 
      # ==== Options
      # +from+:: Sets the path or custom method that resources will be fetched from.
      # +params+:: Sets query and prefix (nested URL) parameters.
      #
      # ==== Examples
      #   Person.find(1)                                         
      #   # => GET /people/1.xml
      #
      #   Person.find(:all)                                      
      #   # => GET /people.xml
      #
      #   Person.find(:all, :params => { :title => "CEO" })      
      #   # => GET /people.xml?title=CEO
      #
      #   Person.find(:first, :from => :managers)                  
      #   # => GET /people/managers.xml
      #
      #   Person.find(:all, :from => "/companies/1/people.xml")  
      #   # => GET /companies/1/people.xml
      #
      #   Person.find(:one, :from => :leader)                    
      #   # => GET /people/leader.xml
      #
      #   Person.find(:one, :from => "/companies/1/manager.xml") 
      #   # => GET /companies/1/manager.xml
      #
      #   StreetAddress.find(1, :params => { :person_id => 1 })  
      #   # => GET /people/1/street_addresses/1.xml
      def find(*arguments)
        scope   = arguments.slice!(0)
        options = arguments.slice!(0) || {}

        case scope
          when :all   then find_every(options)
          when :first then find_every(options).first
          when :one   then find_one(options)
          else             find_single(scope, options)
        end
      end

      # Deletes the resources with the ID in the +id+ parameter.
      #
      # ==== Options
      # All options specify prefix and query parameters.
      #
      # ==== Examples
      #   Event.delete(2)
      #   # => DELETE /events/2
      #
      #   Event.create(:name => 'Free Concert', :location => 'Community Center')
      #   my_event = Event.find(:first)
      #   # => Events (id: 7)
      #   Event.delete(my_event.id)
      #   # => DELETE /events/7
      #
      #   # Let's assume a request to events/5/cancel.xml
      #   Event.delete(params[:id])
      #   # => DELETE /events/5
      #
      def delete(id, options = {})
        connection.delete(element_path(id, options))
      end

      # Asserts the existence of a resource, returning <tt>true</tt> if the resource is found.
      #
      # ==== Examples
      #   Note.create(:title => 'Hello, world.', :body => 'Nothing more for now...')
      #   Note.exists?(1)
      #   # => true
      #
      #   Note.exists(1349)
      #   # => false
      def exists?(id, options = {})
        id && !find_single(id, options).nil?
      rescue ActiveResource::ResourceNotFound
        false
      end

      private
        # Find every resource
        def find_every(options)
          case from = options[:from]
          when Symbol
            instantiate_collection(get(from, options[:params]))
          when String
            path = "#{from}#{query_string(options[:params])}"
            instantiate_collection(connection.get(path, headers) || [])
          else
            prefix_options, query_options = split_options(options[:params])
            path = collection_path(prefix_options, query_options)
            instantiate_collection( (connection.get(path, headers) || []), prefix_options )
          end
        end
        
        # Find a single resource from a one-off URL
        def find_one(options)
          case from = options[:from]
          when Symbol
            instantiate_record(get(from, options[:params]))
          when String
            path = "#{from}#{query_string(options[:params])}"
            instantiate_record(connection.get(path, headers))
          end
        end

        # Find a single resource from the default URL
        def find_single(scope, options)
          prefix_options, query_options = split_options(options[:params])
          path = element_path(scope, prefix_options, query_options)
          instantiate_record(connection.get(path, headers), prefix_options)
        end
        
        def instantiate_collection(collection, prefix_options = {})
          collection.collect! { |record| instantiate_record(record, prefix_options) }
        end

        def instantiate_record(record, prefix_options = {})
          returning new(record) do |resource|
            resource.prefix_options = prefix_options
          end
        end


        # Accepts a URI and creates the site URI from that.
        def create_site_uri_from(site)
          site.is_a?(URI) ? site.dup : URI.parse(site)
        end

        # contains a set of the current prefix parameters.
        def prefix_parameters
          @prefix_parameters ||= prefix_source.scan(/:\w+/).map { |key| key[1..-1].to_sym }.to_set
        end

        # Builds the query string for the request.
        def query_string(options)
          "?#{options.to_query}" unless options.nil? || options.empty? 
        end

        # split an option hash into two hashes, one containing the prefix options, 
        # and the other containing the leftovers.
        def split_options(options = {})
          prefix_options, query_options = {}, {}

          (options || {}).each do |key, value|
            next if key.blank?
            (prefix_parameters.include?(key.to_sym) ? prefix_options : query_options)[key.to_sym] = value
          end

          [ prefix_options, query_options ]
        end
    end

    attr_accessor :attributes #:nodoc:
    attr_accessor :prefix_options #:nodoc:

    # Constructor method for new resources; the optional +attributes+ parameter takes a +Hash+
    # of attributes for the new resource.
    #
    # ==== Examples
    #   my_course = Course.new
    #   my_course.name = "Western Civilization"
    #   my_course.lecturer = "Don Trotter"
    #   my_course.save
    #
    #   my_other_course = Course.new(:name => "Philosophy: Reason and Being", :lecturer => "Ralph Cling")
    #   my_other_course.save
    def initialize(attributes = {})
      @attributes     = {}
      @prefix_options = {}
      load(attributes)
    end

    # A method to determine if the resource a new object (i.e., it has not been POSTed to the remote service yet).
    #
    # ==== Examples
    #   not_new = Computer.create(:brand => 'Apple', :make => 'MacBook', :vendor => 'MacMall')
    #   not_new.new?
    #   # => false
    #
    #   is_new = Computer.new(:brand => 'IBM', :make => 'Thinkpad', :vendor => 'IBM')
    #   is_new.new?
    #   # => true
    #
    #   is_new.save
    #   is_new.new?
    #   # => false
    #
    def new?
      id.nil?
    end

    # Get the +id+ attribute of the resource.
    def id
      attributes[self.class.primary_key]
    end

    # Set the +id+ attribute of the resource.
    def id=(id)
      attributes[self.class.primary_key] = id
    end

    # Allows ActiveResource objects to be used as parameters in ActionPack URL generation.
    def to_param
      id && id.to_s
    end

    # Test for equality.  Resource are equal if and only if +other+ is the same object or 
    # is an instance of the same class, is not +new?+, and has the same +id+.
    #
    # ==== Examples
    #   ryan = Person.create(:name => 'Ryan')
    #   jamie = Person.create(:name => 'Jamie')
    #
    #   ryan == jamie
    #   # => false (Different name attribute and id)
    #
    #   ryan_again = Person.new(:name => 'Ryan')
    #   ryan == ryan_again
    #   # => false (ryan_again is new?)
    #
    #   ryans_clone = Person.create(:name => 'Ryan')
    #   ryan == ryans_clone
    #   # => false (Different id attributes)
    #
    #   ryans_twin = Person.find(ryan.id)
    #   ryan == ryans_twin
    #   # => true
    #
    def ==(other)
      other.equal?(self) || (other.instance_of?(self.class) && !other.new? && other.id == id)
    end

    # Tests for equality (delegates to ==).
    def eql?(other)
      self == other
    end

    # Delegates to id in order to allow two resources of the same type and id to work with something like:
    #   [Person.find(1), Person.find(2)] & [Person.find(1), Person.find(4)] # => [Person.find(1)]
    def hash
      id.hash
    end
    
    # Duplicate the current resource without saving it.
    #
    # ==== Examples
    #   my_invoice = Invoice.create(:customer => 'That Company')
    #   next_invoice = my_invoice.dup
    #   next_invoice.new?
    #   # => true
    #
    #   next_invoice.save
    #   next_invoice == my_invoice
    #   # => false (different id attributes)
    #
    #   my_invoice.customer
    #   # => That Company
    #   next_invoice.customer
    #   # => That Company
    def dup
      returning self.class.new do |resource|
        resource.attributes     = @attributes
        resource.prefix_options = @prefix_options
      end
    end

    # A method to save (+POST+) or update (+PUT+) a resource.  It delegates to +create+ if a new object, 
    # +update+ if it is existing. If the response to the save includes a body, it will be assumed that this body
    # is XML for the final object as it looked after the save (which would include attributes like +created_at+
    # that weren't part of the original submit).
    #
    # ==== Examples
    #   my_company = Company.new(:name => 'RoleModel Software', :owner => 'Ken Auer', :size => 2)
    #   my_company.new?
    #   # => true
    #   my_company.save
    #   # => POST /companies/ (create)
    #
    #   my_company.new?
    #   # => false
    #   my_company.size = 10
    #   my_company.save
    #   # => PUT /companies/1 (update)
    def save
      new? ? create : update
    end

    # Deletes the resource from the remote service.
    #
    # ==== Examples
    #   my_id = 3
    #   my_person = Person.find(my_id)
    #   my_person.destroy
    #   Person.find(my_id)
    #   # => 404 (Resource Not Found)
    #   
    #   new_person = Person.create(:name => 'James')
    #   new_id = new_person.id 
    #   # => 7
    #   new_person.destroy
    #   Person.find(new_id)
    #   # => 404 (Resource Not Found)
    def destroy
      connection.delete(element_path, self.class.headers)
    end

    # Evaluates to <tt>true</tt> if this resource is not +new?+ and is
    # found on the remote service.  Using this method, you can check for
    # resources that may have been deleted between the object's instantiation
    # and actions on it.
    #
    # ==== Examples
    #   Person.create(:name => 'Theodore Roosevelt')
    #   that_guy = Person.find(:first)
    #   that_guy.exists?
    #   # => true
    #
    #   that_lady = Person.new(:name => 'Paul Bean')
    #   that_lady.exists?
    #   # => false
    #
    #   guys_id = that_guy.id
    #   Person.delete(guys_id)
    #   that_guy.exists?
    #   # => false
    def exists?
      !new? && self.class.exists?(id, :params => prefix_options)
    end

    # A method to convert the the resource to an XML string.
    #
    # ==== Options
    # The +options+ parameter is handed off to the +to_xml+ method on each
    # attribute, so it has the same options as the +to_xml+ methods in
    # ActiveSupport.
    #
    # indent:: Set the indent level for the XML output (default is +2+).
    # dasherize:: Boolean option to determine whether or not element names should
    #             replace underscores with dashes (default is +false+).
    # skip_instruct::  Toggle skipping the +instruct!+ call on the XML builder 
    #                  that generates the XML declaration (default is +false+).
    #
    # ==== Examples
    #   my_group = SubsidiaryGroup.find(:first)
    #   my_group.to_xml
    #   # => <?xml version="1.0" encoding="UTF-8"?>
    #   #    <subsidiary_group> [...] </subsidiary_group>
    #
    #   my_group.to_xml(:dasherize => true)
    #   # => <?xml version="1.0" encoding="UTF-8"?>
    #   #    <subsidiary-group> [...] </subsidiary-group>
    #
    #   my_group.to_xml(:skip_instruct => true)
    #   # => <subsidiary_group> [...] </subsidiary_group>
    def to_xml(options={})
      attributes.to_xml({:root => self.class.element_name}.merge(options))
    end

    # A method to reload the attributes of this object from the remote web service.
    #
    # ==== Examples
    #   my_branch = Branch.find(:first)
    #   my_branch.name
    #   # => Wislon Raod
    #   
    #   # Another client fixes the typo...
    #
    #   my_branch.name
    #   # => Wislon Raod
    #   my_branch.reload
    #   my_branch.name
    #   # => Wilson Road
    def reload
      self.load(self.class.find(id, :params => @prefix_options).attributes)
    end

    # A method to manually load attributes from a hash. Recursively loads collections of
    # resources.  This method is called in initialize and create when a +Hash+ of attributes
    # is provided.
    #
    # ==== Examples
    #   my_attrs = {:name => 'J&J Textiles', :industry => 'Cloth and textiles'}
    #
    #   the_supplier = Supplier.find(:first)
    #   the_supplier.name
    #   # => 'J&M Textiles'
    #   the_supplier.load(my_attrs)
    #   the_supplier.name('J&J Textiles')
    #
    #   # These two calls are the same as Supplier.new(my_attrs)
    #   my_supplier = Supplier.new
    #   my_supplier.load(my_attrs)
    #
    #   # These three calls are the same as Supplier.create(my_attrs)
    #   your_supplier = Supplier.new
    #   your_supplier.load(my_attrs)
    #   your_supplier.save
    def load(attributes)
      raise ArgumentError, "expected an attributes Hash, got #{attributes.inspect}" unless attributes.is_a?(Hash)
      @prefix_options, attributes = split_options(attributes)
      attributes.each do |key, value|
        @attributes[key.to_s] =
          case value
            when Array
              resource = find_or_create_resource_for_collection(key)
              value.map { |attrs| resource.new(attrs) }
            when Hash
              resource = find_or_create_resource_for(key)
              resource.new(value)
            else
              value.dup rescue value
          end
      end
      self
    end
    
    # For checking respond_to? without searching the attributes (which is faster).
    alias_method :respond_to_without_attributes?, :respond_to?

    # A method to determine if an object responds to a message (e.g., a method call). In Active Resource, a +Person+ object with a
    # +name+ attribute can answer +true+ to +my_person.respond_to?("name")+, +my_person.respond_to?("name=")+, and
    # +my_person.respond_to?("name?")+.
    def respond_to?(method, include_priv = false)
      method_name = method.to_s
      if attributes.nil?
        return super
      elsif attributes.has_key?(method_name)
        return true 
      elsif ['?','='].include?(method_name.last) && attributes.has_key?(method_name.first(-1))
        return true
      end
      # super must be called at the end of the method, because the inherited respond_to?
      # would return true for generated readers, even if the attribute wasn't present
      super
    end
    

    protected
      def connection(refresh = false)
        self.class.connection(refresh)
      end

      # Update the resource on the remote service.
      def update
        returning connection.put(element_path(prefix_options), to_xml, self.class.headers) do |response|
          load_attributes_from_response(response)
        end
      end

      # Create (i.e., save to the remote service) the new resource.
      def create
        returning connection.post(collection_path, to_xml, self.class.headers) do |response|
          self.id = id_from_response(response)
          load_attributes_from_response(response)
        end
      end
      
      def load_attributes_from_response(response)
        if response['Content-Length'] != "0" && response.body.strip.size > 0
          load(self.class.format.decode(response.body))
        end
      end

      # Takes a response from a typical create post and pulls the ID out
      def id_from_response(response)
        response['Location'][/\/([^\/]*?)(\.\w+)?$/, 1]
      end

      def element_path(options = nil)
        self.class.element_path(id, options || prefix_options)
      end

      def collection_path(options = nil)
        self.class.collection_path(options || prefix_options)
      end

    private
      # Tries to find a resource for a given collection name; if it fails, then the resource is created
      def find_or_create_resource_for_collection(name)
        find_or_create_resource_for(name.to_s.singularize)
      end
      
      # Tries to find a resource for a given name; if it fails, then the resource is created
      def find_or_create_resource_for(name)
        resource_name = name.to_s.camelize

        # FIXME: Make it generic enough to support any depth of module nesting
        if (ancestors = self.class.name.split("::")).size > 1
          begin
            ancestors.first.constantize.const_get(resource_name)
          rescue NameError
            self.class.const_get(resource_name)
          end
        else
          self.class.const_get(resource_name)
        end
      rescue NameError
        resource = self.class.const_set(resource_name, Class.new(ActiveResource::Base))
        resource.prefix = self.class.prefix
        resource.site   = self.class.site
        resource
      end

      def split_options(options = {})
        self.class.send!(:split_options, options)
      end

      def method_missing(method_symbol, *arguments) #:nodoc:
        method_name = method_symbol.to_s

        case method_name.last
          when "="
            attributes[method_name.first(-1)] = arguments.first
          when "?"
            attributes[method_name.first(-1)]
          else
            attributes.has_key?(method_name) ? attributes[method_name] : super
        end
      end
  end
end
