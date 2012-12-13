require 'active_support/core_ext/time/calculations'

module ActionView
  module Helpers
    module Tags
      class DateSelect < Base #:nodoc:
        def initialize(object_name, method_name, template_object, options, html_options)
          @html_options = html_options

          super(object_name, method_name, template_object, options)
        end

        def render
          error_wrapping(datetime_selector(@options, @html_options).send("select_#{select_type}").html_safe)
        end

        class << self
          def select_type
            @select_type ||= self.name.split("::").last.sub("Select", "").downcase
          end
        end

        private

        def select_type
          self.class.select_type
        end

        def datetime_selector(options, html_options)
          datetime = value(object) || default_datetime(options)
          @auto_index ||= nil

          options = options.dup
          options[:field_name]           = @method_name
          options[:include_position]     = true
          options[:prefix]             ||= @object_name
          options[:index]                = @auto_index if @auto_index && !options.has_key?(:index)

          DateTimeSelector.new(datetime, options, html_options)
        end

        def default_datetime(options)
          return if options[:include_blank] || options[:prompt]

          case options[:default]
          when nil
            Time.current
          when Date, Time
            options[:default]
          else
            default = options[:default].dup

            # Rename :minute and :second to :min and :sec
            default[:min] ||= default[:minute]
            default[:sec] ||= default[:second]

            time = Time.current

            [:year, :month, :day, :hour, :min, :sec].each do |key|
              default[key] ||= time.send(key)
            end

            Time.utc(
              default[:year], default[:month], default[:day],
              default[:hour], default[:min], default[:sec]
            )
          end
        end
      end
    end
  end
end
