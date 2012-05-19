require 'active_support/xml_mini'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/string/inflections'

class Array
  # Converts the array to a comma-separated sentence where the last element is joined by the connector word. Options:
  # * <tt>:words_connector</tt> - The sign or word used to join the elements in arrays with two or more elements (default: ", ")
  # * <tt>:two_words_connector</tt> - The sign or word used to join the elements in arrays with two elements (default: " and ")
  # * <tt>:last_word_connector</tt> - The sign or word used to join the last element in arrays with three or more elements (default: ", and ")
  def to_sentence(options = {})
    options.assert_valid_keys(:words_connector, :two_words_connector, :last_word_connector, :locale)

    default_connectors = {
      :words_connector     => ', ',
      :two_words_connector => ' and ',
      :last_word_connector => ', and '
    }
    if defined?(I18n)
      namespace = 'support.array.'
      default_connectors.each_key do |name|
        i18n_key = (namespace + name.to_s).to_sym
        default_connectors[name] = I18n.translate i18n_key, :locale => options[:locale]
      end
    end

    options.reverse_merge! default_connectors

    case length
    when 0
      ''
    when 1
      self[0].to_s.dup
    when 2
      "#{self[0]}#{options[:two_words_connector]}#{self[1]}"
    else
      "#{self[0...-1].join(options[:words_connector])}#{options[:last_word_connector]}#{self[-1]}"
    end
  end

  # Converts a collection of elements into a formatted string by calling
  # <tt>to_s</tt> on all elements and joining them:
  #
  #   Blog.all.to_formatted_s # => "First PostSecond PostThird Post"
  #
  # Adding in the <tt>:db</tt> argument as the format yields a comma separated
  # id list:
  #
  #   Blog.all.to_formatted_s(:db) # => "1,2,3"
  def to_formatted_s(format = :default)
    case format
    when :db
      if empty?
        'null'
      else
        collect { |element| element.id }.join(',')
      end
    else
      to_default_s
    end
  end
  alias_method :to_default_s, :to_s
  alias_method :to_s, :to_formatted_s

  # Returns a string that represents the array in XML by invoking +to_xml+
  # on each element. Active Record collections delegate their representation
  # in XML to this method.
  #
  # All elements are expected to respond to +to_xml+, if any of them does
  # not then an exception is raised.
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
  # Otherwise the root element is "objects":
  #
  #   [{:foo => 1, :bar => 2}, {:baz => 3}].to_xml
  #
  #   <?xml version="1.0" encoding="UTF-8"?>
  #   <objects type="array">
  #     <object>
  #       <bar type="integer">2</bar>
  #       <foo type="integer">1</foo>
  #     </object>
  #     <object>
  #       <baz type="integer">3</baz>
  #     </object>
  #   </objects>
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
  # By default name of the node for the children of root is <tt>root.singularize</tt>.
  # You can change it with the <tt>:children</tt> option.
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
  def to_xml(options = {})
    require 'active_support/builder' unless defined?(Builder)

    options = options.dup
    options[:indent]  ||= 2
    options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    options[:root]    ||= \
      if first.class != Hash && all? { |e| e.is_a?(first.class) }
        underscored = ActiveSupport::Inflector.underscore(first.class.name)
        ActiveSupport::Inflector.pluralize(underscored).tr('/', '_')
      else
        'objects'
      end

    builder = options[:builder]
    builder.instruct! unless options.delete(:skip_instruct)

    root = ActiveSupport::XmlMini.rename_key(options[:root].to_s, options)
    children = options.delete(:children) || root.singularize
    attributes = options[:skip_types] ? {} : {:type => 'array'}

    if empty?
      builder.tag!(root, attributes)
    else
      builder.__send__(:method_missing, root, attributes) do
        each { |value| ActiveSupport::XmlMini.to_tag(children, value, options) }
        yield builder if block_given?
      end
    end
  end
end
