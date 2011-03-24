require 'html/tokenizer'
require 'html/node'
require 'html/selector'
require 'html/sanitizer'

module HTML #:nodoc:
  # A top-level HTMl document. You give it a body of text, and it will parse that
  # text into a tree of nodes.
  class Document #:nodoc:

    # The root of the parsed document.
    attr_reader :root

    # Create a new Document from the given text.
    def initialize(text, strict=false, xml=false)
      tokenizer = Tokenizer.new(text)
      @root = Node.new(nil)
      node_stack = [ @root ]
      while token = tokenizer.next
        node = Node.parse(node_stack.last, tokenizer.line, tokenizer.position, token, strict)

        node_stack.last.children << node unless node.tag? && node.closing == :close
        if node.tag?
          if node_stack.length > 1 && node.closing == :close
            if node_stack.last.name == node.name
              if node_stack.last.children.empty?
                node_stack.last.children << Text.new(node_stack.last, node.line, node.position, "")
              end
              node_stack.pop
            else
              open_start = node_stack.last.position - 20
              open_start = 0 if open_start < 0
              close_start = node.position - 20
              close_start = 0 if close_start < 0
              msg = <<EOF.strip
ignoring attempt to close #{node_stack.last.name} with #{node.name}
  opened at byte #{node_stack.last.position}, line #{node_stack.last.line}
  closed at byte #{node.position}, line #{node.line}
  attributes at open: #{node_stack.last.attributes.inspect}
  text around open: #{text[open_start,40].inspect}
  text around close: #{text[close_start,40].inspect}
EOF
              strict ? raise(msg) : warn(msg)
            end
          elsif !node.childless?(xml) && node.closing != :close
            node_stack.push node
          end
        end
      end
    end

    # Search the tree for (and return) the first node that matches the given
    # conditions. The conditions are interpreted differently for different node
    # types, see HTML::Text#find and HTML::Tag#find.
    def find(conditions)
      @root.find(conditions)
    end

    # Search the tree for (and return) all nodes that match the given
    # conditions. The conditions are interpreted differently for different node
    # types, see HTML::Text#find and HTML::Tag#find.
    def find_all(conditions)
      @root.find_all(conditions)
    end

  end

end
