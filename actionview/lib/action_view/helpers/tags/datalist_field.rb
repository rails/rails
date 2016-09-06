require "action_view/helpers/tags/placeholderable"
require "action_view/helpers/text_helper"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class DatalistField < Base # :nodoc:
        include Placeholderable
        include TextHelper

        def initialize(object_name, method_name, template_object, option_tags, options = {})
          @option_tags = option_tags

          super(object_name, method_name, template_object, options)
        end

        def render
          add_default_name_and_id(@options)
          list_name = @object_name.to_s + "_" + @method_name.to_s.pluralize
          @options["type"] = "text"
          @options["list"] = list_name

          content_tag("input", nil, @options) + content_tag("datalist", @option_tags, id: @options["list"])
        end
      end
    end
  end
end
