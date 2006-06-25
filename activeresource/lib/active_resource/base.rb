require 'active_resource/connection'

module ActiveResource
  class Base
    class << self
      def site=(site)
        @@site = URI.parse(site)
      end
      
      def site
        @@site
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
      
      def element_path(id)
        "/#{collection_name}/#{id}.xml"
      end
      
      def collection_path
        "/#{collection_name}.xml"
      end
      
      def find(*arguments)
        scope = arguments.slice!(0)

        case scope
          when Fixnum
            # { :person => person1 }
            new(connection.get(element_path(scope)).values.first)
          when :all
            # { :people => { :person => [ person1, person2 ] } }
            connection.get(collection_path).values.first.values.first.collect { |element| new(element) }
          when :first
            find(:all, *arguments).first
        end
      end
    end

    attr_accessor :attributes
    
    def initialize(attributes = {})
      @attributes = attributes
    end
    
    def id
      attributes["id"]
    end
    
    def id=(id)
      attributes["id"] = id
    end
    
    def save
      update
    end

    def destroy
      connection.delete(self.class.element_path(id))
    end
    
    def to_xml
      attributes.to_xml(:root => self.class.element_name)
    end
    
    protected
      def connection(refresh = false)
        self.class.connection(refresh)
      end
    
      def update
        connection.put(self.class.element_path(id), to_xml)
      end
    
      def method_missing(method_symbol, *arguments)
        method_name = method_symbol.to_s
        
        case method_name.last
          when "="
            attributes[method_name.first(-1)] = arguments.first
          when "?"
            # TODO
          else
            attributes[method_name] || super
        end
      end
  end
end