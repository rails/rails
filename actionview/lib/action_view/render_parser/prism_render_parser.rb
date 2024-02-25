# frozen_string_literal: true

module ActionView
  module RenderParser
    class PrismRenderParser < Base # :nodoc:
      def render_calls
        queue = [Prism.parse(@code).value]
        templates = []

        while (node = queue.shift)
          queue.concat(node.compact_child_nodes)
          next unless node.is_a?(Prism::CallNode)

          options = render_call_options(node)
          next unless options

          render_type = (options.keys & RENDER_TYPE_KEYS)[0]
          template, object_template = render_call_template(options[render_type])
          next unless template

          if options.key?(:object) || options.key?(:collection) || object_template
            next if options.key?(:object) && options.key?(:collection)
            next unless options.key?(:partial)
          end

          if options[:spacer_template].is_a?(Prism::StringNode)
            templates << partial_to_virtual_path(:partial, options[:spacer_template].unescaped)
          end

          templates << partial_to_virtual_path(render_type, template)

          if render_type != :layout && options[:layout].is_a?(Prism::StringNode)
            templates << partial_to_virtual_path(:layout, options[:layout].unescaped)
          end
        end

        templates
      end

      private
        # Accept a call node and return a hash of options for the render call.
        # If it doesn't match the expected format, return nil.
        def render_call_options(node)
          # We are only looking for calls to render or render_to_string.
          name = node.name.to_sym
          return if name != :render && name != :render_to_string

          # We are only looking for calls with arguments.
          arguments = node.arguments
          return unless arguments

          arguments = arguments.arguments
          length = arguments.length

          # Get rid of any parentheses to get directly to the contents.
          arguments.map! do |argument|
            current = argument

            while current.is_a?(Prism::ParenthesesNode) &&
                  current.body.is_a?(Prism::StatementsNode) &&
                  current.body.body.length == 1
              current = current.body.body.first
            end

            current
          end

          # We are only looking for arguments that are either a string with an
          # array of locals or a keyword hash with symbol keys.
          options =
            if (length == 1 || length == 2) && !arguments[0].is_a?(Prism::KeywordHashNode)
              { partial: arguments[0], locals: arguments[1] }
            elsif length == 1 &&
                  arguments[0].is_a?(Prism::KeywordHashNode) &&
                  arguments[0].elements.all? do |element|
                    element.is_a?(Prism::AssocNode) && element.key.is_a?(Prism::SymbolNode)
                  end
              arguments[0].elements.to_h do |element|
                [element.key.unescaped.to_sym, element.value]
              end
            end

          return unless options

          # Here we validate that the options have the keys we expect.
          keys = options.keys
          return if !keys.intersect?(RENDER_TYPE_KEYS)
          return if (keys - ALL_KNOWN_KEYS).any?

          # Finally, we can return a valid set of options.
          options
        end

        # Accept the node that is being passed in the position of the template
        # and return the template name and whether or not it is an object
        # template.
        def render_call_template(node)
          object_template = false
          template =
            if node.is_a?(Prism::StringNode)
              path = node.unescaped
              path.include?("/") ? path : "#{directory}/#{path}"
            else
              dependency =
                case node.type
                when :class_variable_read_node
                  node.slice[2..]
                when :instance_variable_read_node
                  node.slice[1..]
                when :global_variable_read_node
                  node.slice[1..]
                when :local_variable_read_node
                  node.slice
                when :call_node
                  node.name.to_s
                else
                  return
                end

              "#{dependency.pluralize}/#{dependency.singularize}"
            end

          [template, object_template]
        end
    end
  end
end
