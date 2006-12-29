require 'active_resource/connection'
require 'cgi'
require 'set'

module ActiveResource
  class Base
    # The logger for diagnosing and tracing ARes calls.
    cattr_accessor :logger

    class << self
      def site
        if defined?(@site)
          @site
        elsif superclass != Object and superclass.site
          superclass.site.dup.freeze
        end
      end

      def site=(site)
        @connection = nil
        @site = create_site_uri_from(site)
      end

      def connection(refresh = false)
        @connection = Connection.new(site) if refresh || @connection.nil?
        @connection
      end

      attr_accessor_with_default(:element_name)    { to_s.underscore }
      attr_accessor_with_default(:collection_name) { element_name.pluralize }
      attr_accessor_with_default(:primary_key, 'id')

      def prefix(options={})
        default = site.path
        default << '/' unless default[-1..-1] == '/'
        self.prefix = default
        prefix(options)
      end

      def prefix=(value = '/')
        prefix_call = value.gsub(/:\w+/) { |key| "\#{options[#{key}]}" }
        instance_eval <<-end_eval, __FILE__, __LINE__
          def prefix_source() "#{value}" end
          def prefix(options={}) "#{prefix_call}" end
        end_eval
      rescue
        logger.error "Couldn't set prefix: #{$!}\n  #{method_decl}"
        raise
      end

      alias_method :set_prefix, :prefix=

      alias_method :set_element_name, :element_name=
      alias_method :set_collection_name, :collection_name=

      def element_path(id, options = {})
        "#{prefix(options)}#{collection_name}/#{id}.xml#{query_string(options)}"
      end

      def collection_path(options = {})
        "#{prefix(options)}#{collection_name}.xml#{query_string(options)}"
      end

      alias_method :set_primary_key, :primary_key=

      # Person.find(1) # => GET /people/1.xml
      # StreetAddress.find(1, :person_id => 1) # => GET /people/1/street_addresses/1.xml
      def find(*arguments)
        scope   = arguments.slice!(0)
        options = arguments.slice!(0) || {}

        case scope
          when :all   then find_every(options)
          when :first then find_every(options).first
          else             find_single(scope, options)
        end
      end

      def delete(id)
        connection.delete(element_path(id))
      end

      private
        def find_every(options)
          collection = connection.get(collection_path(options)) || []
          collection.collect! { |element| new(element, options) }
        end

        # { :person => person1 }
        def find_single(scope, options)
          new(connection.get(element_path(scope, options)), options)
        end

        def create_site_uri_from(site)
          site.is_a?(URI) ? site.dup : URI.parse(site)
        end

        def prefix_parameters
          @prefix_parameters ||= prefix_source.scan(/:\w+/).map { |key| key[1..-1].to_sym }.to_set
        end

        def query_string(options)
          # Omit parameters which appear in the URI path.
          query_params = options.reject { |key, value| prefix_parameters.include?(key) }

          # Accumulate a list of escaped key=value pairs for the given parameters.
          pairs = []
          query_params.each do |key, value|
            key = CGI.escape(key.to_s)

            # a => b becomes a=b
            # a => [b, c] becomes a[]=b&a[]=c
            case value
              when Array
                value.each { |val| pairs << "#{key}[]=#{CGI.escape(val.to_s)}" }
              else
                pairs << "#{key}=#{CGI.escape(value.to_s)}"
            end
          end

          "?#{pairs * '&'}" unless pairs.empty?
        end
    end

    attr_accessor :attributes
    attr_accessor :prefix_options

    def initialize(attributes = {}, prefix_options = {})
      @attributes = {}
      self.load attributes
      @prefix_options = prefix_options
    end

    def new?
      id.nil?
    end

    def id
      attributes[self.class.primary_key]
    end

    def id=(id)
      attributes[self.class.primary_key] = id
    end

    # True if and only if +other+ is the same object or is an instance of the same class, is not new?, and has the same id.
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

    def save
      new? ? create : update
    end

    def destroy
      connection.delete(element_path)
    end

    def to_xml(options={})
      attributes.to_xml({:root => self.class.element_name}.merge(options))
    end

    # Reloads the attributes of this object from the remote web service.
    def reload
      self.load self.class.find(id, @prefix_options).attributes
    end

    # Manually load attributes from a hash. Recursively loads collections of
    # resources.
    def load(attributes)
      raise ArgumentError, "expected an attributes Hash, got #{attributes.inspect}" unless attributes.is_a?(Hash)
      attributes.each do |key, value|
        @attributes[key.to_s] =
          case value
            when Array
              resource = find_or_create_resource_for_collection(key)
              value.map { |attrs| resource.new(attrs) }
            when Hash
              resource = find_or_create_resource_for(key)
              resource.new(value)
            when ActiveResource::Base
              value.class.new(value.attributes)
            else
              value.dup rescue value
          end
      end
      self
    end

    protected
      def connection(refresh = false)
        self.class.connection(refresh)
      end

      def update
        connection.put(element_path, to_xml)
      end

      def create
        returning connection.post(collection_path, to_xml) do |response|
          self.id = id_from_response(response)
        end
      end

      # takes a response from a typical create post and pulls the ID out
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
      def find_or_create_resource_for_collection(name)
        find_or_create_resource_for(name.to_s.singularize)
      end

      def find_or_create_resource_for(name)
        resource_name = name.to_s.camelize
        resource_name.constantize
      rescue NameError
        resource = self.class.const_set(resource_name, Class.new(ActiveResource::Base))
        resource.prefix = self.class.prefix
        resource.site   = self.class.site
        resource
      end

      def method_missing(method_symbol, *arguments)
        method_name = method_symbol.to_s

        case method_name.last
          when "="
            attributes[method_name.first(-1)] = arguments.first
          when "?"
            attributes[method_name.first(-1)] == true
          else
            attributes.has_key?(method_name) ? attributes[method_name] : super
        end
      end
  end
end
