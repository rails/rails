require 'active_resource/connection'

module ActiveResource
  class Base
    class << self
      attr_reader :site

      def site=(site)
        @site = site.is_a?(URI) ? site : URI.parse(site)
        @connection = nil
        @site
      end

      def connection(refresh = false)
        @connection = Connection.new(site) if refresh || @connection.nil?
        @connection
      end
      
      def element_name
        self.to_s.underscore
      end

      def collection_name
        element_name.pluralize
      end

      def prefix(options={})
        default = site.path
        default << '/' unless default[-1..-1] == '/'
        self.prefix = default
        prefix(options)
      end
      
      def prefix=(value = '/')
        prefix_call = value.gsub(/:\w+/) { |s| "\#{options[#{s}]}" }
        method_decl = %(def self.prefix(options={}) "#{prefix_call}" end)
        eval method_decl
      end
      alias_method :set_prefix, :prefix=
      
      def element_name=(value)
        class << self ; attr_reader :element_name ; end
        @element_name = value
      end
      alias_method :set_element_name, :element_name=
      
      def collection_name=(value)
        class << self ; attr_reader :collection_name ; end
        @collection_name = value
      end
      alias_method :set_collection_name, :collection_name=

      def element_path(id, options = {})
        "#{prefix(options)}#{collection_name}/#{id}.xml"
      end
      
      def collection_path(options = {})
        "#{prefix(options)}#{collection_name}.xml"
      end
      
      def primary_key
        self.primary_key = 'id'
      end
      
      def primary_key=(value)
        class << self ; attr_reader :primary_key ; end
        @primary_key = value
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

      private
        # { :people => { :person => [ person1, person2 ] } }
        def find_every(options)
          connection.get(collection_path(options)).values.first.values.first.collect { |element| new(element, options) }
        end
        
        # { :person => person1 }
        def find_single(scope, options)
          new(connection.get(element_path(scope, options)).values.first, options)
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
    
    def save
      new? ? create : update
    end

    def destroy
      connection.delete(self.class.element_path(id, prefix_options)[0..-5])
    end

    def to_xml
      attributes.to_xml(:root => self.class.element_name)
    end

    # Reloads the attributes of this object from the remote web service.
    def reload
      self.load self.class.find(id, @prefix_options).attributes
    end

    # Manually load attributes from a hash. Recursively loads collections of
    # resources.
    def load(attributes)
      return self if attributes.nil?
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
        connection.put(self.class.element_path(id, prefix_options)[0..-5], to_xml)
      end

      def create
        returning connection.post(self.class.collection_path(prefix_options)[0..-5], to_xml) do |resp|
          self.id = resp['Location'][/\/([^\/]*?)(\.\w+)?$/, 1]
        end
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
        resource.site = self.class.site
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
