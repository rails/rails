require 'active_resource/connection'
require 'cgi'
require 'set'

module ActiveResource
  class Base
    # The logger for diagnosing and tracing ARes calls.
    cattr_accessor :logger

    class << self
      # Gets the URI of the resource's site
      def site
        if defined?(@site)
          @site
        elsif superclass != Object and superclass.site
          superclass.site.dup.freeze
        end
      end

      # Set the URI for the REST resources
      def site=(site)
        @connection = nil
        @site = create_site_uri_from(site)
      end

      # Base connection to remote service
      def connection(refresh = false)
        @connection = Connection.new(site) if refresh || @connection.nil?
        @connection
      end

      def headers
        @headers ||= {}
      end

      # Do not include any modules in the default element name. This makes it easier to seclude ARes objects
      # in a separate namespace without having to set element_name repeatedly.
      attr_accessor_with_default(:element_name)    { to_s.split("::").last.underscore } #:nodoc:

      attr_accessor_with_default(:collection_name) { element_name.pluralize } #:nodoc:
      attr_accessor_with_default(:primary_key, 'id') #:nodoc:
      
      # Gets the resource prefix
      #  prefix/collectionname/1.xml
      def prefix(options={})
        default = site.path
        default << '/' unless default[-1..-1] == '/'
        # generate the actual method based on the current site path
        self.prefix = default
        prefix(options)
      end

      def prefix_source
        prefix # generate #prefix and #prefix_source methods first
        prefix_source
      end

      # Sets the resource prefix
      #  prefix/collectionname/1.xml
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

      # Gets the element path for the given ID.  If no query_options are given, they are split from the prefix options:
      #
      # Post.element_path(1) # => /posts/1.xml
      # Comment.element_path(1, :post_id => 5) # => /posts/5/comments/1.xml
      # Comment.element_path(1, :post_id => 5, :active => 1) # => /posts/5/comments/1.xml?active=1
      # Comment.element_path(1, {:post_id => 5}, {:active => 1}) # => /posts/5/comments/1.xml?active=1
      def element_path(id, prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}/#{id}.xml#{query_string(query_options)}"
      end

      # Gets the collection path.  If no query_options are given, they are split from the prefix options:
      #
      # Post.collection_path # => /posts.xml
      # Comment.collection_path(:post_id => 5) # => /posts/5/comments.xml
      # Comment.collection_path(:post_id => 5, :active => 1) # => /posts/5/comments.xml?active=1
      # Comment.collection_path({:post_id => 5}, {:active => 1}) # => /posts/5/comments.xml?active=1
      def collection_path(prefix_options = {}, query_options = nil)
        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{collection_name}.xml#{query_string(query_options)}"
      end

      alias_method :set_primary_key, :primary_key=  #:nodoc:

      # Create a new resource instance and request to the remote service
      # that it be saved.  This is equivalent to the following simultaneous calls:
      #
      #   ryan = Person.new(:first => 'ryan')
      #   ryan.save
      #
      # The newly created resource is returned.  If a failure has occurred an
      # exception will be raised (see save).  If the resource is invalid and
      # has not been saved then <tt>resource.valid?</tt> will return <tt>false</tt>,
      # while <tt>resource.new?</tt> will still return <tt>true</tt>.
      #      
      def create(attributes = {})
        returning(self.new(attributes)) { |res| res.save }        
      end

      # Core method for finding resources.  Used similarly to Active Record's find method.
      #
      #   Person.find(1)                                         # => GET /people/1.xml
      #   Person.find(:all)                                      # => GET /people.xml
      #   Person.find(:all, :params => { :title => "CEO" })      # => GET /people.xml?title=CEO
      #   Person.find(:all, :from => :managers)                  # => GET /people/managers.xml
      #   Person.find(:all, :from => "/companies/1/people.xml")  # => GET /companies/1/people.xml
      #   Person.find(:one, :from => :leader)                    # => GET /people/leader.xml
      #   Person.find(:one, :from => "/companies/1/manager.xml") # => GET /companies/1/manager.xml
      #   StreetAddress.find(1, :params => { :person_id => 1 })  # => GET /people/1/street_addresses/1.xml
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

      def delete(id, options = {})
        connection.delete(element_path(id, options))
      end

      # Evalutes to <tt>true</tt> if the resource is found.
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

    def initialize(attributes = {})
      @attributes     = {}
      @prefix_options = {}
      load(attributes)
    end

    # Is the resource a new object?
    def new?
      id.nil?
    end

    # Get the id of the object.
    def id
      attributes[self.class.primary_key]
    end

    # Set the id of the object.
    def id=(id)
      attributes[self.class.primary_key] = id
    end

    # True if and only if +other+ is the same object or is an instance of the same class, is not +new?+, and has the same +id+.
    def ==(other)
      other.equal?(self) || (other.instance_of?(self.class) && !other.new? && other.id == id)
    end

    # Delegates to ==
    def eql?(other)
      self == other
    end

    # Delegates to id in order to allow two resources of the same type and id to work with something like:
    #   [Person.find(1), Person.find(2)] & [Person.find(1), Person.find(4)] # => [Person.find(1)]
    def hash
      id.hash
    end
    
    def dup
      returning new do |resource|
        resource.attributes     = @attributes
        resource.prefix_options = @prefix_options
      end
    end

    # Delegates to +create+ if a new object, +update+ if its old. If the response to the save includes a body,
    # it will be assumed that this body is XML for the final object as it looked after the save (which would include
    # attributes like created_at that wasn't part of the original submit).
    def save
      new? ? create : update
    end

    # Delete the resource.
    def destroy
      connection.delete(element_path, self.class.headers)
    end

    # Evaluates to <tt>true</tt> if this resource is found.
    def exists?
      !new? && self.class.exists?(id, :params => prefix_options)
    end

    # Convert the resource to an XML string
    def to_xml(options={})
      attributes.to_xml({:root => self.class.element_name}.merge(options))
    end

    # Reloads the attributes of this object from the remote web service.
    def reload
      self.load(self.class.find(id, @prefix_options).attributes)
    end

    # Manually load attributes from a hash. Recursively loads collections of
    # resources.
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

    # A Person object with a name attribute can ask person.respond_to?("name"), person.respond_to?("name="), and
    # person.respond_to?("name?") which will all return true.
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
        if response['Content-size'] != "0" && response.body.strip.size > 0
          load(connection.xml_from_response(response))
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
        self.class.send(:split_options, options)
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
