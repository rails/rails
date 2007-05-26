module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module Conversions
        # Converts the array to comma-seperated sentence where the last element is joined by the connector word. Options:
        # * <tt>:connector</tt>: The word used to join the last element in arrays with two or more elements (default: "and")
        # * <tt>:skip_last_comma</tt>: Set to true to return "a, b and c" instead of "a, b, and c".
        def to_sentence(options = {})
          options.assert_valid_keys(:connector, :skip_last_comma)
          options.reverse_merge! :connector => 'and', :skip_last_comma => false
          
          case length
          	when 0
          		""
            when 1
              self[0]
            when 2
              "#{self[0]} #{options[:connector]} #{self[1]}"
            else
              "#{self[0...-1].join(', ')}#{options[:skip_last_comma] ? '' : ','} #{options[:connector]} #{self[-1]}"
          end
        end

        # When an array is given to url_for, it is converted to a slash separated string.
        def to_param
          join '/'
        end
        
        def self.included(klass) #:nodoc:
          klass.send(:alias_method, :to_default_s, :to_s)
          klass.send(:alias_method, :to_s, :to_formatted_s)
        end
        
        def to_formatted_s(format = :default)
          case format
            when :db
              if respond_to?(:empty?) && self.empty?
                "null"
              else
                collect { |element| element.id }.join(",")
              end
            else
              to_default_s
          end
        end
        
        def to_xml(options = {})
          raise "Not all elements respond to to_xml" unless all? { |e| e.respond_to? :to_xml }

          options[:root]     ||= all? { |e| e.is_a?(first.class) && first.class.to_s != "Hash" } ? first.class.to_s.underscore.pluralize : "records"
          options[:children] ||= options[:root].singularize
          options[:indent]   ||= 2
          options[:builder]  ||= Builder::XmlMarkup.new(:indent => options[:indent])

          root     = options.delete(:root).to_s
          children = options.delete(:children)

          if !options.has_key?(:dasherize) || options[:dasherize]
            root = root.dasherize
          end

          options[:builder].instruct! unless options.delete(:skip_instruct)

          opts = options.merge({ :root => children })

          options[:builder].tag!(root) {
            yield options[:builder] if block_given?
            each { |e| e.to_xml(opts.merge!({ :skip_instruct => true })) }
          }
        end

      end
    end
  end
end
