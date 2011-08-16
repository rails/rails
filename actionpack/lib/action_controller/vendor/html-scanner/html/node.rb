require 'strscan'

module HTML #:nodoc:

  class Conditions < Hash #:nodoc:
    def initialize(hash)
      super()
      hash = { :content => hash } unless Hash === hash
      hash = keys_to_symbols(hash)
      hash.each do |k,v|
        case k
          when :tag, :content then
            # keys are valid, and require no further processing
          when :attributes then
            hash[k] = keys_to_strings(v)
          when :parent, :child, :ancestor, :descendant, :sibling, :before,
                  :after
            hash[k] = Conditions.new(v)
          when :children
            hash[k] = v = keys_to_symbols(v)
            v.each do |k,v2|
              case k
                when :count, :greater_than, :less_than
                  # keys are valid, and require no further processing
                when :only
                  v[k] = Conditions.new(v2)
                else
                  raise "illegal key #{k.inspect} => #{v2.inspect}"
              end
            end
          else
            raise "illegal key #{k.inspect} => #{v.inspect}"
        end
      end
      update hash
    end

    private

      def keys_to_strings(hash)
        Hash[hash.keys.map {|k| [k.to_s, hash[k]]}]
      end

      def keys_to_symbols(hash)
        Hash[hash.keys.map do |k|
          raise "illegal key #{k.inspect}" unless k.respond_to?(:to_sym)
          [k.to_sym, hash[k]]
        end]
      end
  end

  # The base class of all nodes, textual and otherwise, in an HTML document.
  class Node #:nodoc:
    # The array of children of this node. Not all nodes have children.
    attr_reader :children

    # The parent node of this node. All nodes have a parent, except for the
    # root node.
    attr_reader :parent

    # The line number of the input where this node was begun
    attr_reader :line

    # The byte position in the input where this node was begun
    attr_reader :position

    # Create a new node as a child of the given parent.
    def initialize(parent, line=0, pos=0)
      @parent = parent
      @children = []
      @line, @position = line, pos
    end

    # Return a textual representation of the node.
    def to_s
      @children.join()
    end

    # Return false (subclasses must override this to provide specific matching
    # behavior.) +conditions+ may be of any type.
    def match(conditions)
      false
    end

    # Search the children of this node for the first node for which #find
    # returns non +nil+. Returns the result of the #find call that succeeded.
    def find(conditions)
      conditions = validate_conditions(conditions)
      @children.each do |child|
        node = child.find(conditions)
        return node if node
      end
      nil
    end

    # Search for all nodes that match the given conditions, and return them
    # as an array.
    def find_all(conditions)
      conditions = validate_conditions(conditions)

      matches = []
      matches << self if match(conditions)
      @children.each do |child|
        matches.concat child.find_all(conditions)
      end
      matches
    end

    # Returns +false+. Subclasses may override this if they define a kind of
    # tag.
    def tag?
      false
    end

    def validate_conditions(conditions)
      Conditions === conditions ? conditions : Conditions.new(conditions)
    end

    def ==(node)
      return false unless self.class == node.class && children.size == node.children.size

      equivalent = true

      children.size.times do |i|
        equivalent &&= children[i] == node.children[i]
      end

      equivalent
    end

    class <<self
      def parse(parent, line, pos, content, strict=true)
        if content !~ /^<\S/
          Text.new(parent, line, pos, content)
        else
          scanner = StringScanner.new(content)

          unless scanner.skip(/</)
            if strict
              raise "expected <"
            else
              return Text.new(parent, line, pos, content)
            end
          end

          if scanner.skip(/!\[CDATA\[/)
            unless scanner.skip_until(/\]\]>/)
              if strict
                raise "expected ]]> (got #{scanner.rest.inspect} for #{content})"
              else
                scanner.skip_until(/\Z/)
              end
            end

            return CDATA.new(parent, line, pos, scanner.pre_match.gsub(/<!\[CDATA\[/, ''))
          end

          closing = ( scanner.scan(/\//) ? :close : nil )
          return Text.new(parent, line, pos, content) unless name = scanner.scan(/[^\s!>\/]+/)
          name.downcase!

          unless closing
            scanner.skip(/\s*/)
            attributes = {}
            while attr = scanner.scan(/[-\w:]+/)
              value = true
              if scanner.scan(/\s*=\s*/)
                if delim = scanner.scan(/['"]/)
                  value = ""
                  while text = scanner.scan(/[^#{delim}\\]+|./)
                    case text
                      when "\\" then
                        value << text
                        break if scanner.eos?
                        value << scanner.getch
                      when delim
                        break
                      else value << text
                    end
                  end
                else
                  value = scanner.scan(/[^\s>\/]+/)
                end
              end
              attributes[attr.downcase] = value
              scanner.skip(/\s*/)
            end

            closing = ( scanner.scan(/\//) ? :self : nil )
          end

          unless scanner.scan(/\s*>/)
            if strict
              raise "expected > (got #{scanner.rest.inspect} for #{content}, #{attributes.inspect})"
            else
              # throw away all text until we find what we're looking for
              scanner.skip_until(/>/) or scanner.terminate
            end
          end

          Tag.new(parent, line, pos, name, attributes, closing)
        end
      end
    end
  end

  # A node that represents text, rather than markup.
  class Text < Node #:nodoc:

    attr_reader :content

    # Creates a new text node as a child of the given parent, with the given
    # content.
    def initialize(parent, line, pos, content)
      super(parent, line, pos)
      @content = content
    end

    # Returns the content of this node.
    def to_s
      @content
    end

    # Returns +self+ if this node meets the given conditions. Text nodes support
    # conditions of the following kinds:
    #
    # * if +conditions+ is a string, it must be a substring of the node's
    #   content
    # * if +conditions+ is a regular expression, it must match the node's
    #   content
    # * if +conditions+ is a hash, it must contain a <tt>:content</tt> key that
    #   is either a string or a regexp, and which is interpreted as described
    #   above.
    def find(conditions)
      match(conditions) && self
    end

    # Returns non-+nil+ if this node meets the given conditions, or +nil+
    # otherwise. See the discussion of #find for the valid conditions.
    def match(conditions)
      case conditions
        when String
          @content == conditions
        when Regexp
          @content =~ conditions
        when Hash
          conditions = validate_conditions(conditions)

          # Text nodes only have :content, :parent, :ancestor
          unless (conditions.keys - [:content, :parent, :ancestor]).empty?
            return false
          end

          match(conditions[:content])
        else
          nil
      end
    end

    def ==(node)
      return false unless super
      content == node.content
    end
  end

  # A CDATA node is simply a text node with a specialized way of displaying
  # itself.
  class CDATA < Text #:nodoc:
    def to_s
      "<![CDATA[#{super}]]>"
    end
  end

  # A Tag is any node that represents markup. It may be an opening tag, a
  # closing tag, or a self-closing tag. It has a name, and may have a hash of
  # attributes.
  class Tag < Node #:nodoc:

    # Either +nil+, <tt>:close</tt>, or <tt>:self</tt>
    attr_reader :closing

    # Either +nil+, or a hash of attributes for this node.
    attr_reader :attributes

    # The name of this tag.
    attr_reader :name

    # Create a new node as a child of the given parent, using the given content
    # to describe the node. It will be parsed and the node name, attributes and
    # closing status extracted.
    def initialize(parent, line, pos, name, attributes, closing)
      super(parent, line, pos)
      @name = name
      @attributes = attributes
      @closing = closing
    end

    # A convenience for obtaining an attribute of the node. Returns +nil+ if
    # the node has no attributes.
    def [](attr)
      @attributes ? @attributes[attr] : nil
    end

    # Returns non-+nil+ if this tag can contain child nodes.
    def childless?(xml = false)
      return false if xml && @closing.nil?
      !@closing.nil? ||
        @name =~ /^(img|br|hr|link|meta|area|base|basefont|
                    col|frame|input|isindex|param)$/ox
    end

    # Returns a textual representation of the node
    def to_s
      if @closing == :close
        "</#{@name}>"
      else
        s = "<#{@name}"
        @attributes.each do |k,v|
          s << " #{k}"
          s << "=\"#{v}\"" if String === v
        end
        s << " /" if @closing == :self
        s << ">"
        @children.each { |child| s << child.to_s }
        s << "</#{@name}>" if @closing != :self && !@children.empty?
        s
      end
    end

    # If either the node or any of its children meet the given conditions, the
    # matching node is returned. Otherwise, +nil+ is returned. (See the
    # description of the valid conditions in the +match+ method.)
    def find(conditions)
      match(conditions) && self || super
    end

    # Returns +true+, indicating that this node represents an HTML tag.
    def tag?
      true
    end

    # Returns +true+ if the node meets any of the given conditions. The
    # +conditions+ parameter must be a hash of any of the following keys
    # (all are optional):
    #
    # * <tt>:tag</tt>: the node name must match the corresponding value
    # * <tt>:attributes</tt>: a hash. The node's values must match the
    #   corresponding values in the hash.
    # * <tt>:parent</tt>: a hash. The node's parent must match the
    #   corresponding hash.
    # * <tt>:child</tt>: a hash. At least one of the node's immediate children
    #   must meet the criteria described by the hash.
    # * <tt>:ancestor</tt>: a hash. At least one of the node's ancestors must
    #   meet the criteria described by the hash.
    # * <tt>:descendant</tt>: a hash. At least one of the node's descendants
    #   must meet the criteria described by the hash.
    # * <tt>:sibling</tt>: a hash. At least one of the node's siblings must
    #   meet the criteria described by the hash.
    # * <tt>:after</tt>: a hash. The node must be after any sibling meeting
    #   the criteria described by the hash, and at least one sibling must match.
    # * <tt>:before</tt>: a hash. The node must be before any sibling meeting
    #   the criteria described by the hash, and at least one sibling must match.
    # * <tt>:children</tt>: a hash, for counting children of a node. Accepts the
    #   keys:
    # ** <tt>:count</tt>: either a number or a range which must equal (or
    #    include) the number of children that match.
    # ** <tt>:less_than</tt>: the number of matching children must be less than
    #    this number.
    # ** <tt>:greater_than</tt>: the number of matching children must be
    #    greater than this number.
    # ** <tt>:only</tt>: another hash consisting of the keys to use
    #    to match on the children, and only matching children will be
    #    counted.
    #
    # Conditions are matched using the following algorithm:
    #
    # * if the condition is a string, it must be a substring of the value.
    # * if the condition is a regexp, it must match the value.
    # * if the condition is a number, the value must match number.to_s.
    # * if the condition is +true+, the value must not be +nil+.
    # * if the condition is +false+ or +nil+, the value must be +nil+.
    #
    # Usage:
    #
    #   # test if the node is a "span" tag
    #   node.match :tag => "span"
    #
    #   # test if the node's parent is a "div"
    #   node.match :parent => { :tag => "div" }
    #
    #   # test if any of the node's ancestors are "table" tags
    #   node.match :ancestor => { :tag => "table" }
    #
    #   # test if any of the node's immediate children are "em" tags
    #   node.match :child => { :tag => "em" }
    #
    #   # test if any of the node's descendants are "strong" tags
    #   node.match :descendant => { :tag => "strong" }
    #
    #   # test if the node has between 2 and 4 span tags as immediate children
    #   node.match :children => { :count => 2..4, :only => { :tag => "span" } }
    #
    #   # get funky: test to see if the node is a "div", has a "ul" ancestor
    #   # and an "li" parent (with "class" = "enum"), and whether or not it has
    #   # a "span" descendant that contains # text matching /hello world/:
    #   node.match :tag => "div",
    #              :ancestor => { :tag => "ul" },
    #              :parent => { :tag => "li",
    #                           :attributes => { :class => "enum" } },
    #              :descendant => { :tag => "span",
    #                               :child => /hello world/ }
    def match(conditions)
      conditions = validate_conditions(conditions)
      # check content of child nodes
      if conditions[:content]
        if children.empty?
          return false unless match_condition("", conditions[:content])
        else
          return false unless children.find { |child| child.match(conditions[:content]) }
        end
      end

      # test the name
      return false unless match_condition(@name, conditions[:tag]) if conditions[:tag]

      # test attributes
      (conditions[:attributes] || {}).each do |key, value|
        return false unless match_condition(self[key], value)
      end

      # test parent
      return false unless parent.match(conditions[:parent]) if conditions[:parent]

      # test children
      return false unless children.find { |child| child.match(conditions[:child]) } if conditions[:child]

      # test ancestors
      if conditions[:ancestor]
        return false unless catch :found do
          p = self
          throw :found, true if p.match(conditions[:ancestor]) while p = p.parent
        end
      end

      # test descendants
      if conditions[:descendant]
        return false unless children.find do |child|
          # test the child
          child.match(conditions[:descendant]) ||
          # test the child's descendants
          child.match(:descendant => conditions[:descendant])
        end
      end

      # count children
      if opts = conditions[:children]
        matches = children.select do |c|
          (c.kind_of?(HTML::Tag) and (c.closing == :self or ! c.childless?))
        end

        matches = matches.select { |c| c.match(opts[:only]) } if opts[:only]
        opts.each do |key, value|
          next if key == :only
          case key
            when :count
              if Integer === value
                return false if matches.length != value
              else
                return false unless value.include?(matches.length)
              end
            when :less_than
              return false unless matches.length < value
            when :greater_than
              return false unless matches.length > value
            else raise "unknown count condition #{key}"
          end
        end
      end

      # test siblings
      if conditions[:sibling] || conditions[:before] || conditions[:after]
        siblings = parent ? parent.children : []
        self_index = siblings.index(self)

        if conditions[:sibling]
          return false unless siblings.detect do |s|
            s != self && s.match(conditions[:sibling])
          end
        end

        if conditions[:before]
          return false unless siblings[self_index+1..-1].detect do |s|
            s != self && s.match(conditions[:before])
          end
        end

        if conditions[:after]
          return false unless siblings[0,self_index].detect do |s|
            s != self && s.match(conditions[:after])
          end
        end
      end

      true
    end

    def ==(node)
      return false unless super
      return false unless closing == node.closing && self.name == node.name
      attributes == node.attributes
    end

    private
      # Match the given value to the given condition.
      def match_condition(value, condition)
        case condition
          when String
            value && value == condition
          when Regexp
            value && value.match(condition)
          when Numeric
            value == condition.to_s
          when true
            !value.nil?
          when false, nil
            value.nil?
          else
            false
        end
      end
  end
end
