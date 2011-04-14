require 'active_support/xml_mini'
require 'active_support/time'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'

class Hash
  # Returns a string containing an XML representation of its receiver:
  #
  #   {"foo" => 1, "bar" => 2}.to_xml
  #   # =>
  #   # <?xml version="1.0" encoding="UTF-8"?>
  #   # <hash>
  #   #   <foo type="integer">1</foo>
  #   #   <bar type="integer">2</bar>
  #   # </hash>
  #
  # To do so, the method loops over the pairs and builds nodes that depend on
  # the _values_. Given a pair +key+, +value+:
  #
  # * If +value+ is a hash there's a recursive call with +key+ as <tt>:root</tt>.
  #
  # * If +value+ is an array there's a recursive call with +key+ as <tt>:root</tt>,
  #   and +key+ singularized as <tt>:children</tt>.
  #
  # * If +value+ is a callable object it must expect one or two arguments. Depending
  #   on the arity, the callable is invoked with the +options+ hash as first argument
  #   with +key+ as <tt>:root</tt>, and +key+ singularized as second argument. Its
  #   return value becomes a new node.
  #
  # * If +value+ responds to +to_xml+ the method is invoked with +key+ as <tt>:root</tt>.
  #
  # * Otherwise, a node with +key+ as tag is created with a string representation of
  #   +value+ as text node. If +value+ is +nil+ an attribute "nil" set to "true" is added.
  #   Unless the option <tt>:skip_types</tt> exists and is true, an attribute "type" is
  #   added as well according to the following mapping:
  #
  #     XML_TYPE_NAMES = {
  #       "Symbol"     => "symbol",
  #       "Fixnum"     => "integer",
  #       "Bignum"     => "integer",
  #       "BigDecimal" => "decimal",
  #       "Float"      => "float",
  #       "TrueClass"  => "boolean",
  #       "FalseClass" => "boolean",
  #       "Date"       => "date",
  #       "DateTime"   => "datetime",
  #       "Time"       => "datetime"
  #     }
  #
  # By default the root node is "hash", but that's configurable via the <tt>:root</tt> option.
  #
  # The default XML builder is a fresh instance of <tt>Builder::XmlMarkup</tt>. You can
  # configure your own builder with the <tt>:builder</tt> option. The method also accepts
  # options like <tt>:dasherize</tt> and friends, they are forwarded to the builder.
  def to_xml(options = {})
    require 'active_support/builder' unless defined?(Builder)

    options = options.dup
    options[:indent]  ||= 2
    options[:root]    ||= "hash"
    options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])

    builder = options[:builder]
    builder.instruct! unless options.delete(:skip_instruct)

    root = ActiveSupport::XmlMini.rename_key(options[:root].to_s, options)

    builder.__send__(:method_missing, root) do
      each { |key, value| ActiveSupport::XmlMini.to_tag(key, value, options) }
      yield builder if block_given?
    end
  end

  class << self
    def from_xml(xml)
      typecast_xml_value(unrename_keys(ActiveSupport::XmlMini.parse(xml)))
    end

    private
      def typecast_xml_value(value)
        case value.class.to_s
          when 'Hash'
            if value['type'] == 'array'
              _, entries = Array.wrap(value.detect { |k,v| k != 'type' })
              if entries.nil? || (c = value['__content__'] && c.blank?)
                []
              else
                case entries.class.to_s   # something weird with classes not matching here.  maybe singleton methods breaking is_a?
                when "Array"
                  entries.collect { |v| typecast_xml_value(v) }
                when "Hash"
                  [typecast_xml_value(entries)]
                else
                  raise "can't typecast #{entries.inspect}"
                end
              end
            elsif value['type'] == 'file' || value["__content__"].present?
              content = value["__content__"]
              if parser = ActiveSupport::XmlMini::PARSING[value["type"]]
                parser.arity == 1 ? parser.call(content) : parser.call(content, value)
              else
                content
              end
            elsif value['type'] == 'string' && value['nil'] != 'true'
              ""
            # blank or nil parsed values are represented by nil
            elsif value.blank? || value['nil'] == 'true'
              nil
            # If the type is the only element which makes it then
            # this still makes the value nil, except if type is
            # a XML node(where type['value'] is a Hash)
            elsif value['type'] && value.size == 1 && !value['type'].is_a?(::Hash)
              nil
            else
              xml_value = value.inject({}) do |h,(k,v)|
                h[k] = typecast_xml_value(v)
                h
              end

              # Turn { :files => { :file => #<StringIO> } into { :files => #<StringIO> } so it is compatible with
              # how multipart uploaded files from HTML appear
              xml_value["file"].is_a?(StringIO) ? xml_value["file"] : xml_value
            end
          when 'Array'
            value.map! { |i| typecast_xml_value(i) }
            value.length > 1 ? value : value.first
          when 'String'
            value
          else
            raise "can't typecast #{value.class.name} - #{value.inspect}"
        end
      end

      def unrename_keys(params)
        case params.class.to_s
          when "Hash"
            params.inject({}) do |h,(k,v)|
              h[k.to_s.tr("-", "_")] = unrename_keys(v)
              h
            end
          when "Array"
            params.map { |v| unrename_keys(v) }
          else
            params
        end
      end
  end
end
