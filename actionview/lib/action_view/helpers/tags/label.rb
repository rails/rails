module ActionView
  module Helpers
    module Tags # :nodoc:
      class Label < Base # :nodoc:
        def initialize(object_name, method_name, template_object, content_or_options = nil, options = nil)
          options ||= {}

          content_is_options = content_or_options.is_a?(Hash)
          if content_is_options
            options.merge! content_or_options
            @content = nil
          else
            @content = content_or_options
          end

          super(object_name, method_name, template_object, options)
        end

        FOR = 'for'.freeze
        ID  = 'id'.freeze

        def render(&block)
          options = @options.stringify_keys
          tag_value = options.delete("value".freeze)
          name_and_id = options.dup

          if name_and_id[FOR]
            name_and_id[ID] = name_and_id[FOR]
          else
            name_and_id.delete(ID)
          end

          add_default_name_and_id_for_value(tag_value, name_and_id)
          options.delete("index".freeze)
          options.delete("namespace".freeze)
          options.delete("multiple".freeze)
          options[FOR] = name_and_id[ID] unless options.key?(FOR)

          if block_given?
            content = @template_object.capture(&block)
          else
            content = if @content.blank?
                        @object_name.gsub!(/\[(.*)_attributes\]\[\d\]/, '.\1')
                        method_and_value = tag_value.present? ? "#{@method_name}.#{tag_value}" : @method_name

                        if object.respond_to?(:to_model)
                          key = object.class.model_name.i18n_key
                          i18n_default = ["#{key}.#{method_and_value}".to_sym, "".freeze]
                        end

                        i18n_default ||= "".freeze
                        I18n.t("#{@object_name}.#{method_and_value}", :default => i18n_default, :scope => "helpers.label".freeze).presence
                      else
                        @content.to_s
                      end

            content ||= if object && object.class.respond_to?(:human_attribute_name)
                          object.class.human_attribute_name(@method_name)
                        end

            content ||= @method_name.humanize
          end

          label_tag(name_and_id[ID], content, options)
        end
      end
    end
  end
end
