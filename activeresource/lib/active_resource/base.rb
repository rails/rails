require 'active_resource/connection'

module ActiveResource
  class Base
    class << self
      attr_reader :site

      def site=(site)
        @site = site.is_a?(URI) ? site : URI.parse(site)
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
        set_prefix default
        prefix(options)
      end
      
      def set_prefix(value = '/')
        prefix_call = value.gsub(/:\w+/) { |s| "\#{options[#{s}]}" }
        method_decl = %(def self.prefix(options={}) "#{prefix_call}" end)
        eval method_decl
      end
      
      def set_element_name(value)
        class << self ; attr_reader :element_name ; end
        @element_name = value
      end
      
      def set_collection_name(value)
        class << self ; attr_reader :collection_name ; end
        @collection_name = value
      end

      def element_path(id, options = {})
        "#{prefix(options)}#{collection_name}/#{id}.xml"
      end
      
      def collection_path(options = {})
        "#{prefix(options)}#{collection_name}.xml"
      end
      
      def primary_key
        set_primary_key 'id'
      end
      
      def set_primary_key(value)
        class << self ; attr_reader :primary_key ; end
        @primary_key = value
      end
      
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
      @attributes     = attributes
      @prefix_options = prefix_options
    end

    def new_resource?
      id.nil?
    end

    def id
      attributes[self.class.primary_key]
    end
    
    def id=(id)
      attributes[self.class.primary_key] = id
    end
    
    def save
      new_resource? ? create : update
    end

    def destroy
      connection.delete(self.class.element_path(id, prefix_options)[0..-5])
    end
    
    def to_xml
      attributes.to_xml(:root => self.class.element_name)
    end

    # Reloads the attributes of this object from the remote web service.
    def reload
      @attributes.update(self.class.find(self.id, @prefix_options).instance_variable_get(:@attributes))
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
