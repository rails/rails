require 'active_support/core_ext/hash/conversions'

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
    # <tt>:skip_instruct</tt>, <tt>:skip_types</tt>, <tt>:dasherize</tt> and <tt>:camelize</tt> .
    # The <tt>:only</tt> and <tt>:except</tt> options are the same as for the
    # +attributes+ method. The default is to dasherize all column names, but you
    # can disable this setting <tt>:dasherize</tt> to +false+. Setting <tt>:camelize</tt>
    # to +true+ will camelize all column names - this also overrides <tt>:dasherize</tt>.
    # To not have the column type included in the XML output set <tt>:skip_types</tt> to +true+.
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
    # Additionally, the record being serialized will be passed to a Proc's second
    # parameter.  This allows for ad hoc additions to the resultant document that
    # incorporate the context of the record being serialized. And by leveraging the
    # closure created by a Proc, to_xml can be used to add elements that normally fall
    # outside of the scope of the model -- for example, generating and appending URLs
    # associated with models.
    # 
    #   proc = Proc.new { |options, record| options[:builder].tag!('name-reverse', record.name.reverse) }
    #   firm.to_xml :procs => [ proc ]
    #
    #   <firm>
    #     # ... normal attributes as shown above ...
    #     <name-reverse>slangis73</name-reverse>
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

  class XmlSerializer < ActiveModel::Serializers::Xml::Serializer #:nodoc:
    include Serialization::RecordSerializer

    def serializable_attributes
      serializable_attribute_names.collect { |name| Attribute.new(name, @serializable) }
    end

    def serializable_method_attributes
      Array(options[:methods]).inject([]) do |method_attributes, name|
        method_attributes << MethodAttribute.new(name.to_s, @serializable) if @serializable.respond_to?(name.to_s)
        method_attributes
      end
    end

    def add_associations(association, records, opts)
      if records.is_a?(Enumerable)
        tag = reformat_name(association.to_s)
        type = options[:skip_types] ? {} : {:type => "array"}

        if records.empty?
          builder.tag!(tag, type)
        else
          builder.tag!(tag, type) do
            association_name = association.to_s.singularize
            records.each do |record|
              if options[:skip_types]
                record_type = {}
              else
                record_class = (record.class.to_s.underscore == association_name) ? nil : record.class.name
                record_type = {:type => record_class}
              end

              record.to_xml opts.merge(:root => association_name).merge(record_type)
            end
          end
        end
      else
        if record = @serializable.send(association)
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

    class Attribute < ActiveModel::Serializers::Xml::Serializer::Attribute #:nodoc:
      protected
        def compute_type
          type = @serializable.class.serialized_attributes.has_key?(name) ? :yaml : @serializable.class.columns_hash[name].type

          case type
            when :text
              :string
            when :time
              :datetime
            else
              type
          end
        end
    end

    class MethodAttribute < Attribute #:nodoc:
      protected
        def compute_type
          Hash::XML_TYPE_NAMES[@serializable.send(name).class.name] || :string
        end
    end
  end
end
