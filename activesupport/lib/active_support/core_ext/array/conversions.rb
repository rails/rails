module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module Conversions
        # Converts the array to comma-seperated sentence where the last element is joined by the connector word. Options:
        # * <tt>:connector</tt>: The word used to join the last element in arrays with more than two elements (default: "and")
        # * <tt>:skip_last_comma</tt>: Set to true to return "a, b, and c" instead of "a, b and c".
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
        
        def to_xml(options = {})
          raise "Not all elements respond to to_xml" unless all? { |e| e.respond_to? :to_xml }

          options[:root]     ||= all? { |e| e.is_a?(first.class) && first.class.to_s != "Hash" } ? first.class.to_s.underscore.pluralize : "records"
          options[:children] ||= options[:root].singularize
          options[:indent]   ||= 2
          options[:builder]  ||= Builder::XmlMarkup.new(:indent => options[:indent])

          root     = options.delete(:root)
          children = options.delete(:children)

          options[:builder].instruct! unless options.delete(:skip_instruct)
          options[:builder].tag!(root.to_s.dasherize) { each { |e| e.to_xml(options.merge({ :skip_instruct => true, :root => children })) } }
        end
      end
    end
  end
end
