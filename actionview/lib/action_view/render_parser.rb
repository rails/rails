# frozen_string_literal: true

require "prism"

module ActionView
  class RenderParser # :nodoc:
    ALL_KNOWN_KEYS = [:partial, :template, :layout, :formats, :locals, :object, :collection, :as, :status, :content_type, :location, :spacer_template].freeze
    RENDER_TYPE_KEYS = [:partial, :template, :layout].freeze
    RENDER_CALL_METHODS = /\A(render|render_to_string)\z/
    LAYOUT_CALL_METHOD = /\Alayout\z/

    RenderCallInfo = Struct.new(:virtual_path, :locals_keys)

    def initialize(name, code, from_controller: false)
      @name = name
      @code = code
      @from_controller = from_controller
    end

    def render_calls
      collect_render_calls.map(&:virtual_path)
    end

    def render_calls_with_locals
      collect_render_calls
    end

    private
      def collect_render_calls
        queue = [Prism.parse(@code).value]
        results = []

        while (node = queue.shift)
          queue.concat(node.compact_child_nodes)
          next unless node.is_a?(Prism::CallNode)

          if @from_controller && node.name.to_s.match?(LAYOUT_CALL_METHOD) && !node.receiver && node.arguments
            call = parse_layout_call(node)
            results << call if call
            next
          end

          options = render_call_options(node)
          next unless options

          render_type = (options.keys & RENDER_TYPE_KEYS)[0]
          template, object_template = render_call_template(options[render_type])
          next unless template

          locals_keys = extract_locals_keys(options, render_type, template, object_template)
          next unless locals_keys

          if options[:spacer_template].is_a?(Prism::StringNode)
            results << RenderCallInfo.new(
              partial_to_virtual_path(:partial, options[:spacer_template].unescaped),
              locals_keys.dup
            )
          end

          results << RenderCallInfo.new(
            partial_to_virtual_path(render_type, template),
            locals_keys
          )

          if render_type != :layout && options[:layout].is_a?(Prism::StringNode)
            results << RenderCallInfo.new(
              partial_to_virtual_path(:layout, options[:layout].unescaped),
              locals_keys.dup
            )
          end
        end

        results
      end

      def directory
        File.dirname(@name)
      end

      def partial_to_virtual_path(render_type, partial_path)
        if render_type == :partial || render_type == :layout
          partial_path.gsub(%r{(/|^)([^/]*)\z}, '\1_\2')
        else
          partial_path
        end
      end

      def extract_locals_keys(options, render_type, template, object_template)
        locals_keys = []

        if options.key?(:locals)
          locals_node = options[:locals]
          if locals_node.is_a?(Prism::HashNode) || locals_node.is_a?(Prism::KeywordHashNode)
            if locals_node.elements.all? { |e| e.is_a?(Prism::AssocNode) && e.key.is_a?(Prism::SymbolNode) }
              locals_keys = locals_node.elements.map { |e| e.key.unescaped.to_sym }
            else
              return nil
            end
          elsif !locals_node.nil?
            return nil
          end
        end

        if options.key?(:object) || options.key?(:collection) || object_template
          return nil if options.key?(:object) && options.key?(:collection)
          return nil unless options.key?(:partial)

          as = if options.key?(:as)
            parse_symbol_or_string(options[:as])
          else
            File.basename(template)[/\A_?(.*?)(?:\.\w+)*\z/, 1]
          end
          return nil unless as

          locals_keys << as.to_sym
          if options.key?(:collection)
            locals_keys << :"#{as}_counter"
            locals_keys << :"#{as}_iteration"
          end
        end

        locals_keys.sort!
        locals_keys
      end

      def parse_symbol_or_string(node)
        if node.is_a?(Prism::SymbolNode)
          node.unescaped
        elsif node.is_a?(Prism::StringNode)
          node.unescaped
        end
      end

      def parse_layout_call(node)
        arguments = node.arguments.arguments
        return unless arguments.length == 1

        arg = arguments[0]
        return unless arg.is_a?(Prism::StringNode)

        virtual_path = "layouts/#{arg.unescaped}"
        RenderCallInfo.new(virtual_path, [])
      end

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
            if @from_controller
              # In controller context, render("foo") means render(template: "foo")
              { template: arguments[0], locals: arguments[1] }
            else
              { partial: arguments[0], locals: arguments[1] }
            end
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
          case node.type
          when :string_node
            path = node.unescaped
            path.include?("/") ? path : "#{directory}/#{path}"
          when :interpolated_string_node
            node.parts.map do |node|
              case node.type
              when :string_node
                node.unescaped
              when :embedded_statements_node
                "*"
              else
                return
              end
            end.join("")
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

            object_template = true
            "#{dependency.pluralize}/#{dependency.singularize}"
          end

        [template, object_template]
      end
  end
end
