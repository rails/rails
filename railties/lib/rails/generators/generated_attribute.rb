require 'active_support/time'
require 'active_support/core_ext/object/inclusion'

module Rails
  module Generators
    class GeneratedAttribute
      attr_accessor :name, :type

      def initialize(name, type)
        raise Thor::Error, "Missing type for attribute '#{name}'.\nExample: '#{name}:string' where string is the type." if type.blank?
        @name, @type = name, type.to_sym
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

      def reference?
        self.type.in?([:references, :belongs_to])
      end
    end
  end
end
