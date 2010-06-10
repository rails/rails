require 'active_support/time'

module Rails
  module Generators
    class GeneratedAttribute
      attr_accessor :name, :type

      def initialize(name, type)
        @name, @type = name, type.to_sym
      end

      def field_type
        @field_type ||= case type
          when :integer, :float, :decimal then :text_field
          when :time                      then :time_select
          when :datetime, :timestamp      then :datetime_select
          when :date                      then :date_select
          when :text                      then :text_area
          when :boolean                   then :check_box
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
          when :string                      then "MyString"
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
        [ :references, :belongs_to ].include?(self.type)
      end
    end
  end
end
