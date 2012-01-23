require 'active_support/time'
require 'active_support/core_ext/object/inclusion'
require 'active_support/core_ext/object/blank'

module Rails
  module Generators
    class GeneratedAttribute
      attr_accessor :name, :type
      attr_reader   :attr_options

      class << self
        def parse(column_definition)
          name, type, has_index = column_definition.split(':')

          # if user provided "name:index" instead of "name:string:index"
          # type should be set blank so GeneratedAttribute's constructor
          # could set it to :string
          has_index, type = type, nil if %w(index uniq).include?(type)

          type, attr_options = *parse_type_and_options(type)
          new(name, type, has_index, attr_options)
        end

        private

        # parse possible attribute options like :limit for string/text/binary/integer or :precision/:scale for decimals
        # when declaring options curly brackets should be used
        def parse_type_and_options(type)
          case type
          when /(string|text|binary|integer)\{(\d+)\}/
            return $1, :limit => $2.to_i
          when /decimal\{(\d+)(,|\.|\-)(\d+)\}/
            return :decimal, :precision => $1.to_i, :scale => $3.to_i
          else
            return type, {}
          end
        end
      end

      def initialize(name, type=nil, index_type=false, attr_options={})
        @name           = name
        @type           = (type.presence || :string).to_sym
        @has_index      = %w(index uniq).include?(index_type)
        @has_uniq_index = %w(uniq).include?(index_type)
        @attr_options   = attr_options
      end

      def field_type
        @field_type ||= case type
          when :integer              then :number_field
          when :float, :decimal      then :text_field
          when :time                 then :time_select
          when :datetime, :timestamp then :datetime_select
          when :date                 then :date_select
          when :text                 then :text_area
          when :boolean              then :check_box
          else
            :text_field
        end
      end

      def default
        @default ||= case type
          when :integer                     then 1
          when :float                       then 1.5
          when :decimal                     then "9.99"
          when :datetime, :timestamp, :time then Time.now.to_s(:db)
          when :date                        then Date.today.to_s(:db)
          when :string                      then name == "type" ? "" : "MyString"
          when :text                        then "MyText"
          when :boolean                     then false
          when :references, :belongs_to     then nil
          else
            ""
        end
      end

      def human_name
        name.to_s.humanize
      end

      def index_name
        reference? ? "#{name}_id" : name
      end

      def reference?
        self.type.in?([:references, :belongs_to])
      end

      def has_index?
        @has_index
      end

      def has_uniq_index?
        @has_uniq_index
      end

      def inject_options
        "".tap { |s| @attr_options.each { |k,v| s << ", :#{k} => #{v.inspect}" } }
      end

      def inject_index_options
        has_uniq_index? ? ", :unique => true" : ''
      end
    end
  end
end
