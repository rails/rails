require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/hash/conversions'

module ActiveModel
  module Serializers
    module Xml
      extend ActiveSupport::Concern

      class Serializer < ActiveModel::Serializer #:nodoc:
        class Attribute #:nodoc:
          attr_reader :name, :value, :type

          def initialize(name, serializable)
            @name, @serializable = name, serializable
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
              value = @serializable.send(name)
              type = Hash::XML_TYPE_NAMES[value.class.name]
              type ||= :string if value.respond_to?(:to_str)
              type ||= :yaml
              type
            end

            def compute_value
              value = @serializable.send(name)

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
              Hash::XML_TYPE_NAMES[@serializable.send(name).class.name] || :string
            end
        end

        def builder
          @builder ||= begin
            require 'builder' unless defined? ::Builder
            options[:indent] ||= 2
            builder = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])

            unless options[:skip_instruct]
              builder.instruct!
              options[:skip_instruct] = true
            end

            builder
          end
        end

        def root
          root = (options[:root] || @serializable.class.model_name.singular).to_s
          reformat_name(root)
        end

        def dasherize?
          !options.has_key?(:dasherize) || options[:dasherize]
        end

        def camelize?
          options.has_key?(:camelize) && options[:camelize]
        end

        def serializable_attributes
          serializable_attribute_names.collect { |name| Attribute.new(name, @serializable) }
        end

        def serializable_method_attributes
          Array(options[:methods]).inject([]) do |methods, name|
            methods << MethodAttribute.new(name.to_s, @serializable) if @serializable.respond_to?(name.to_s)
            methods
          end
        end

        def serialize
          args = [root]

          if options[:namespace]
            args << {:xmlns => options[:namespace]}
          end

          if options[:type]
            args << {:type => options[:type]}
          end

          builder.tag!(*args) do
            add_attributes
            procs = options.delete(:procs)
            options[:procs] = procs
            add_procs
            yield builder if block_given?
          end
        end

        private
          def reformat_name(name)
            name = name.camelize if camelize?
            dasherize? ? name.dasherize : name
          end

          def add_attributes
            (serializable_attributes + serializable_method_attributes).each do |attribute|
              builder.tag!(
                reformat_name(attribute.name),
                attribute.value.to_s,
                attribute.decorations(!options[:skip_types])
              )
            end
          end

          def add_procs
            if procs = options.delete(:procs)
              [ *procs ].each do |proc|
                if proc.arity > 1
                  proc.call(options, @serializable)
                else
                  proc.call(options)
                end
              end
            end
          end
      end

      def to_xml(options = {}, &block)
        serializer = Serializer.new(self, options)
        block_given? ? serializer.to_s(&block) : serializer.to_s
      end

      def from_xml(xml)
        self.attributes = Hash.from_xml(xml).values.first
        self
      end
    end
  end
end
