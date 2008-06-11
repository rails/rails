module ActiveRecord #:nodoc:
  module Serialization
    # Builds an XML document to represent the model. Some configuration is
    # available through +options+. However more complicated cases should
    # override ActiveRecord::Base#to_xml.
    #
    # By default the generated XML document will include the processing
    # instruction and all the object's attributes. For example:
    #
    #   <?xml version="1.0" encoding="UTF-8"?>
    #   <topic>
    #     <title>The First Topic</title>
    #     <author-name>David</author-name>
    #     <id type="integer">1</id>
    #     <approved type="boolean">false</approved>
    #     <replies-count type="integer">0</replies-count>
    #     <bonus-time type="datetime">2000-01-01T08:28:00+12:00</bonus-time>
    #     <written-on type="datetime">2003-07-16T09:28:00+1200</written-on>
    #     <content>Have a nice day</content>
    #     <author-email-address>david@loudthinking.com</author-email-address>
    #     <parent-id></parent-id>
    #     <last-read type="date">2004-04-15</last-read>
    #   </topic>
    #
    # This behavior can be controlled with <tt>:only</tt>, <tt>:except</tt>,
    # <tt>:skip_instruct</tt>, <tt>:skip_types</tt> and <tt>:dasherize</tt>.
    # The <tt>:only</tt> and <tt>:except</tt> options are the same as for the
    # +attributes+ method. The default is to dasherize all column names, but you
    # can disable this setting <tt>:dasherize</tt> to +false+. To not have the
    # column type included in the XML output set <tt>:skip_types</tt> to +true+.
    #
    # For instance:
    #
    #   topic.to_xml(:skip_instruct => true, :except => [ :id, :bonus_time, :written_on, :replies_count ])
    #
    #   <topic>
    #     <title>The First Topic</title>
    #     <author-name>David</author-name>
    #     <approved type="boolean">false</approved>
    #     <content>Have a nice day</content>
    #     <author-email-address>david@loudthinking.com</author-email-address>
    #     <parent-id></parent-id>
    #     <last-read type="date">2004-04-15</last-read>
    #   </topic>
    #
    # To include first level associations use <tt>:include</tt>:
    #
    #   firm.to_xml :include => [ :account, :clients ]
    #
    #   <?xml version="1.0" encoding="UTF-8"?>
    #   <firm>
    #     <id type="integer">1</id>
    #     <rating type="integer">1</rating>
    #     <name>37signals</name>
    #     <clients type="array">
    #       <client>
    #         <rating type="integer">1</rating>
    #         <name>Summit</name>
    #       </client>
    #       <client>
    #         <rating type="integer">1</rating>
    #         <name>Microsoft</name>
    #       </client>
    #     </clients>
    #     <account>
    #       <id type="integer">1</id>
    #       <credit-limit type="integer">50</credit-limit>
    #     </account>
    #   </firm>
    #
    # To include deeper levels of associations pass a hash like this:
    #
    #   firm.to_xml :include => {:account => {}, :clients => {:include => :address}}
    #   <?xml version="1.0" encoding="UTF-8"?>
    #   <firm>
    #     <id type="integer">1</id>
    #     <rating type="integer">1</rating>
    #     <name>37signals</name>
    #     <clients type="array">
    #       <client>
    #         <rating type="integer">1</rating>
    #         <name>Summit</name>
    #         <address>
    #           ...
    #         </address>
    #       </client>
    #       <client>
    #         <rating type="integer">1</rating>
    #         <name>Microsoft</name>
    #         <address>
    #           ...
    #         </address>
    #       </client>
    #     </clients>
    #     <account>
    #       <id type="integer">1</id>
    #       <credit-limit type="integer">50</credit-limit>
    #     </account>
    #   </firm>
    #
    # To include any methods on the model being called use <tt>:methods</tt>:
    #
    #   firm.to_xml :methods => [ :calculated_earnings, :real_earnings ]
    #
    #   <firm>
    #     # ... normal attributes as shown above ...
    #     <calculated-earnings>100000000000000000</calculated-earnings>
    #     <real-earnings>5</real-earnings>
    #   </firm>
    #
    # To call any additional Procs use <tt>:procs</tt>. The Procs are passed a
    # modified version of the options hash that was given to +to_xml+:
    #
    #   proc = Proc.new { |options| options[:builder].tag!('abc', 'def') }
    #   firm.to_xml :procs => [ proc ]
    #
    #   <firm>
    #     # ... normal attributes as shown above ...
    #     <abc>def</abc>
    #   </firm>
    #
    # Alternatively, you can yield the builder object as part of the +to_xml+ call:
    #
    #   firm.to_xml do |xml|
    #     xml.creator do
    #       xml.first_name "David"
    #       xml.last_name "Heinemeier Hansson"
    #     end
    #   end
    #
    #   <firm>
    #     # ... normal attributes as shown above ...
    #     <creator>
    #       <first_name>David</first_name>
    #       <last_name>Heinemeier Hansson</last_name>
    #     </creator>
    #   </firm>
    #
    # As noted above, you may override +to_xml+ in your ActiveRecord::Base
    # subclasses to have complete control about what's generated. The general
    # form of doing this is:
    #
    #   class IHaveMyOwnXML < ActiveRecord::Base
    #     def to_xml(options = {})
    #       options[:indent] ||= 2
    #       xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    #       xml.instruct! unless options[:skip_instruct]
    #       xml.level_one do
    #         xml.tag!(:second_level, 'content')
    #       end
    #     end
    #   end
    def to_xml(options = {}, &block)
      serializer = XmlSerializer.new(self, options)
      block_given? ? serializer.to_s(&block) : serializer.to_s
    end

    def from_xml(xml)
      self.attributes = Hash.from_xml(xml).values.first
      self
    end
  end

  class XmlSerializer < ActiveRecord::Serialization::Serializer #:nodoc:
    def builder
      @builder ||= begin
        options[:indent] ||= 2
        builder = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])

        unless options[:skip_instruct]
          builder.instruct!
          options[:skip_instruct] = true
        end

        builder
      end
    end

    def root
      root = (options[:root] || @record.class.to_s.underscore).to_s
      dasherize? ? root.dasherize : root
    end

    def dasherize?
      !options.has_key?(:dasherize) || options[:dasherize]
    end

    def serializable_attributes
      serializable_attribute_names.collect { |name| Attribute.new(name, @record) }
    end

    def serializable_method_attributes
      Array(options[:methods]).inject([]) do |method_attributes, name|
        method_attributes << MethodAttribute.new(name.to_s, @record) if @record.respond_to?(name.to_s)
        method_attributes
      end
    end

    def add_attributes
      (serializable_attributes + serializable_method_attributes).each do |attribute|
        add_tag(attribute)
      end
    end

    def add_procs
      if procs = options.delete(:procs)
        [ *procs ].each do |proc|
          proc.call(options)
        end
      end
    end

    def add_tag(attribute)
      builder.tag!(
        dasherize? ? attribute.name.dasherize : attribute.name,
        attribute.value.to_s,
        attribute.decorations(!options[:skip_types])
      )
    end

    def add_associations(association, records, opts)
      if records.is_a?(Enumerable)
        tag = association.to_s
        tag = tag.dasherize if dasherize?
        if records.empty?
          builder.tag!(tag, :type => :array)
        else
          builder.tag!(tag, :type => :array) do
            association_name = association.to_s.singularize
            records.each do |record|
              record.to_xml opts.merge(
                :root => association_name,
                :type => (record.class.to_s.underscore == association_name ? nil : record.class.name)
              )
            end
          end
        end
      else
        if record = @record.send(association)
          record.to_xml(opts.merge(:root => association))
        end
      end
    end

    def serialize
      args = [root]
      if options[:namespace]
        args << {:xmlns=>options[:namespace]}
      end

      if options[:type]
        args << {:type=>options[:type]}
      end

      builder.tag!(*args) do
        add_attributes
        procs = options.delete(:procs)
        add_includes { |association, records, opts| add_associations(association, records, opts) }
        options[:procs] = procs
        add_procs
        yield builder if block_given?
      end
    end

    class Attribute #:nodoc:
      attr_reader :name, :value, :type

      def initialize(name, record)
        @name, @record = name, record

        @type  = compute_type
        @value = compute_value
      end

      # There is a significant speed improvement if the value
      # does not need to be escaped, as <tt>tag!</tt> escapes all values
      # to ensure that valid XML is generated. For known binary
      # values, it is at least an order of magnitude faster to
      # Base64 encode binary values and directly put them in the
      # output XML than to pass the original value or the Base64
      # encoded value to the <tt>tag!</tt> method. It definitely makes
      # no sense to Base64 encode the value and then give it to
      # <tt>tag!</tt>, since that just adds additional overhead.
      def needs_encoding?
        ![ :binary, :date, :datetime, :boolean, :float, :integer ].include?(type)
      end

      def decorations(include_types = true)
        decorations = {}

        if type == :binary
          decorations[:encoding] = 'base64'
        end

        if include_types && type != :string
          decorations[:type] = type
        end

        if value.nil?
          decorations[:nil] = true
        end

        decorations
      end

      protected
        def compute_type
          type = @record.class.serialized_attributes.has_key?(name) ? :yaml : @record.class.columns_hash[name].type

          case type
            when :text
              :string
            when :time
              :datetime
            else
              type
          end
        end

        def compute_value
          value = @record.send(name)

          if formatter = Hash::XML_FORMATTING[type.to_s]
            value ? formatter.call(value) : nil
          else
            value
          end
        end
    end

    class MethodAttribute < Attribute #:nodoc:
      protected
        def compute_type
          Hash::XML_TYPE_NAMES[@record.send(name).class.name] || :string
        end
    end
  end
end
