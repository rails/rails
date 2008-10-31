require 'builder'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module Conversions
        # Converts the array to a comma-separated sentence where the last element is joined by the connector word. Options:
        # * <tt>:connector</tt> - The word used to join the last element in arrays with two or more elements (default: "and")
        # * <tt>:skip_last_comma</tt> - Set to true to return "a, b and c" instead of "a, b, and c".        
        def to_sentence(options = {})          
          options.assert_valid_keys(:connector, :skip_last_comma, :locale)
          
          default = I18n.translate(:'support.array.sentence_connector', :locale => options[:locale])
          default_skip_last_comma = I18n.translate(:'support.array.skip_last_comma', :locale => options[:locale])
          options.reverse_merge! :connector => default, :skip_last_comma => default_skip_last_comma
          options[:connector] = "#{options[:connector]} " unless options[:connector].nil? || options[:connector].strip == ''

          case length
            when 0
              ""
            when 1
              self[0].to_s
            when 2
              "#{self[0]} #{options[:connector]}#{self[1]}"
            else
              "#{self[0...-1].join(', ')}#{options[:skip_last_comma] ? '' : ','} #{options[:connector]}#{self[-1]}"
          end
        end
        

        # Calls <tt>to_param</tt> on all its elements and joins the result with
        # slashes. This is used by <tt>url_for</tt> in Action Pack. 
        def to_param
          collect { |e| e.to_param }.join '/'
        end

        # Converts an array into a string suitable for use as a URL query string,
        # using the given +key+ as the param name.
        #
        #   ['Rails', 'coding'].to_query('hobbies') # => "hobbies%5B%5D=Rails&hobbies%5B%5D=coding"
        def to_query(key)
          prefix = "#{key}[]"
          collect { |value| value.to_query(prefix) }.join '&'
        end

        def self.included(base) #:nodoc:
          base.class_eval do
            alias_method :to_default_s, :to_s
            alias_method :to_s, :to_formatted_s
          end
        end

        # Converts a collection of elements into a formatted string by calling
        # <tt>to_s</tt> on all elements and joining them:
        #
        #   Blog.find(:all).to_formatted_s # => "First PostSecond PostThird Post"
        #
        # Adding in the <tt>:db</tt> argument as the format yields a prettier
        # output:
        #
        #   Blog.find(:all).to_formatted_s(:db) # => "First Post,Second Post,Third Post"
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

        # Returns a string that represents this array in XML by sending +to_xml+
        # to each element. Active Record collections delegate their representation
        # in XML to this method.
        #
        # All elements are expected to respond to +to_xml+, if any of them does
        # not an exception is raised.
        #
        # The root node reflects the class name of the first element in plural
        # if all elements belong to the same type and that's not Hash:
        #
        #   customer.projects.to_xml
        #
        #   <?xml version="1.0" encoding="UTF-8"?>
        #   <projects type="array">
        #     <project>
        #       <amount type="decimal">20000.0</amount>
        #       <customer-id type="integer">1567</customer-id>
        #       <deal-date type="date">2008-04-09</deal-date>
        #       ...
        #     </project>
        #     <project>
        #       <amount type="decimal">57230.0</amount>
        #       <customer-id type="integer">1567</customer-id>
        #       <deal-date type="date">2008-04-15</deal-date>
        #       ...
        #     </project>
        #   </projects>
        #
        # Otherwise the root element is "records":
        #
        #   [{:foo => 1, :bar => 2}, {:baz => 3}].to_xml
        #
        #   <?xml version="1.0" encoding="UTF-8"?>
        #   <records type="array">
        #     <record>
        #       <bar type="integer">2</bar>
        #       <foo type="integer">1</foo>
        #     </record>
        #     <record>
        #       <baz type="integer">3</baz>
        #     </record>
        #   </records>
        #
        # If the collection is empty the root element is "nil-classes" by default:
        #
        #   [].to_xml
        #
        #   <?xml version="1.0" encoding="UTF-8"?>
        #   <nil-classes type="array"/>
        #
        # To ensure a meaningful root element use the <tt>:root</tt> option:
        #
        #   customer_with_no_projects.projects.to_xml(:root => "projects")
        #
        #   <?xml version="1.0" encoding="UTF-8"?>
        #   <projects type="array"/>
        #
        # By default root children have as node name the one of the root
        # singularized. You can change it with the <tt>:children</tt> option.
        #
        # The +options+ hash is passed downwards:
        #
        #   Message.all.to_xml(:skip_types => true)
        #
        #   <?xml version="1.0" encoding="UTF-8"?>
        #   <messages>
        #     <message>
        #       <created-at>2008-03-07T09:58:18+01:00</created-at>
        #       <id>1</id>
        #       <name>1</name>
        #       <updated-at>2008-03-07T09:58:18+01:00</updated-at>
        #       <user-id>1</user-id>
        #     </message>
        #   </messages>
        #
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

          xml = options[:builder]
          if empty?
            xml.tag!(root, options[:skip_types] ? {} : {:type => "array"})
          else
            xml.tag!(root, options[:skip_types] ? {} : {:type => "array"}) {
              yield xml if block_given?
              each { |e| e.to_xml(opts.merge({ :skip_instruct => true })) }
            }
          end
        end

      end
    end
  end
end
