# frozen_string_literal: true

require "pp"

module ActiveSupport
  # Note that this is a module _constructor_: to use it, you need to
  # call it as a method and then #include the result.
  #
  # Returns a module that defines pretty-printing (PP) methods to
  # display the given attributes. Note that unlike the default
  # Object#inspect only the listed attributes will be included. This
  # allows the caller to constrain the detail shown, and focus on an
  # object's identifying characteristics and operational data, while
  # skipping over e.g. cached values and owning-object references that
  # could cause huge object trees to be enumerated.
  #
  #
  # Each attribute is an identifier to be evaluated in the context of the
  # object: undecorated names are assumed to be methods, while instance
  # variables may be accessed by their "@"-prefixed name.
  #
  # Attributes can also be specified as a hash, in which case the key is
  # the label to be displayed, and the value is the attribute to be
  # inspected (or a proc that will be called to obtain the value).
  #
  # Before the attributes appear in the output, space is reserved for an
  # optional object +label+, which is intended to be a short value
  # identifying the object instance.
  #
  # To customize the label, pass a block that returns a string, or set
  # the +label:+ parameter to a symbol to call that method on the
  # instance being inspected.
  #
  # +label+ may produce an array, in which case the elements will be
  # rendered in order, with each element separated by whitespace.
  # Strings are inserted in the output unmodified; this provides more
  # control over the output, but means #inspect should be used for
  # displaying unknown values to retain proper formatting. Any element
  # that is not an array or a string will be recursively pretty-printed.
  #
  # By default the built-in object address (e.g. 0x0123456789abcdef),
  # which appears in the standard Kernel#inspect output, is not
  # included. To add it, pass +id: true+. This can be useful when
  # objects are otherwise indistinguishable, but makes for more
  # cluttered output. The expectation is that most classes defining
  # custom inspection will provide sufficient detail in the label and/or
  # attributes to identify the instance.
  #
  #
  # When this module is included, if the target class/module does not
  # have a specific #to_s method, an additional ToString module will
  # automatically be included, which will provide a #to_s method that
  # produces a subset of the #inspect output. (Specifically, the class
  # name and object id / label, but not the attributes.)
  #
  #
  # ==== Example
  #
  #  class User
  #    def initialize(id, username, name, interests, password_digest)
  #      @id = id
  #      @username = username
  #      @name = name
  #      @interests = interests
  #      @password_digest = password_digest
  #    end
  #  end
  #
  #  user = User.new(77, "jdoe", "John Doe", ["sports", "music"],
  #                  "61bc77ec652ed6ace7a8eb44...")
  #
  #  # Default Ruby behavior:
  #
  #  user.inspect #=> "#<User:0x00007f9b8f8b9840 @id=77, @username=\"jdoe\", @name=\"John Doe\", @interests=[\"sports\", \"music\"], @password_digest=\"61bc77ec652ed6ace7a8eb44...\">"
  #  user.to_s #=> "#<User:0x00007f9b8f8b9840>"
  #
  #  pp user #=>
  #  > #<User:0x0000000113695bb8
  #  >  @id=77,
  #  >  @interests=["sports", "music"],
  #  >  @name="John Doe",
  #  >  @password_digest="61bc77ec652ed6ace7a8eb44...",
  #  >  @username="jdoe">
  #
  #  # After defining a custom Inspect for the User class:
  #
  #  class User
  #    include ActiveSupport::Inspect(:@name, { interests: -> { @interests.size } }) { [@id, @username.to_s] }
  #  end
  #
  #  user.inspect #=> "#<User 77 \"jdoe\" @name=\"John Doe\" interests=2>"
  #  user.to_s #=> "#<User 77 \"jdoe\">"
  #
  #  pp user #=>
  #  > #<User 77 "jdoe"
  #  >   @name="John Doe"
  #  >   interests=2>
  #
  def self.Inspect(*attributes, label: nil, id: false, &block)
    Inspect.new(id: id, label: label || block, attributes: attributes, source_location: caller_locations(1, 1)[0])
  end

  class Inspect < ::Module # :nodoc:
    UNDEF = Object.new
    BASIC_EVAL = ::BasicObject.instance_method(:instance_eval)
    BASIC_EXEC = ::BasicObject.instance_method(:instance_exec)
    BASIC_ID = ::BasicObject.instance_method(:__id__)
    KERNEL_CLASS = ::Kernel.instance_method(:class)
    KERNEL_TO_S = ::Kernel.instance_method(:to_s)
    MODULE_NAME = ::Module.instance_method(:name)
    MODULE_TO_S = ::Module.instance_method(:to_s)

    class ToString < ::Module # :nodoc:
      def initialize(inspect_module)
        define_method(:to_s) { inspect_module.pretty_string_for(self) }
      end
    end

    def initialize(id:, label:, attributes:, source_location: nil)
      @id = id
      @label = expand_label(label)
      @attributes = expand_attributes(attributes)
      @source_location = source_location

      inspect_module = self
      define_method(:pretty_print) { |q| inspect_module.pretty_print_object(q, self) }
      define_method(:pretty_print_cycle) { |q| inspect_module.pretty_print_object(q, self, true) }

      alias_method :inspect, :pretty_print_inspect

      @string_module = ToString.new(inspect_module)
    end

    def pretty_print_object(q, obj, cycle = false)
      leader, opener, closer = pretty_identifier_parts(obj)

      q.text leader

      if pretty_label(q, opener, obj, cycle)
        opener = nil
      end

      if cycle
        if opener
          q.text opener
          q.group(1) do
            q.breakable ""
            q.text "..."
          end
        else
          q.group(1) do
            q.breakable
            q.text "..."
          end
        end
      else
        if pretty_attributes(q, opener, obj)
          opener = nil
        end
      end

      q.text closer unless opener

      q
    end

    def pretty_string_for(obj)
      s = "".dup
      q = defined?(::PP::SingleLine) ? ::PP::SingleLine.new(s) : ::PP.new(s, 9999)

      q.guard_inspect_key do
        leader, opener, closer = pretty_identifier_parts(obj)

        q.text leader

        if pretty_label(q, opener, obj, false)
          opener = nil
        end

        q.text closer unless opener
      end
      q.flush

      s
    end

    private
      attr_reader :id, :label, :attributes, :source_location

      def included(target)
        # Our #to_s is marginally better than Kernel or Module's, but
        # not an improvement on any other inherited attempt.
        owner = target.instance_method(:to_s).owner
        if ::Kernel == owner || ::Module == owner
          target.include @string_module
        end
      end

      def expand_label(label)
        case label
        when ::Symbol
          -> { __send__(label).inspect }
        when ::Proc, nil
          label
        else
          raise ::ArgumentError, "label must be a Symbol or Proc"
        end
      end

      def expand_attributes(attributes)
        attribute_map = {}
        attributes.flatten.each_with_index do |attribute, idx|
          case attribute
          when ::Symbol, ::String
            attribute_map[attribute.to_s] = attribute.to_s
          when ::Hash
            attribute.each do |key, value|
              attribute_map[key.to_s] =
                if value.is_a?(::Proc)
                  value
                else
                  value.to_s
                end
            end
          when ::Proc
            attribute_map[idx] = attribute
          end
        end
        attribute_map
      end

      def pretty_attributes(q, opener, obj)
        attribute_values = {}
        @attributes.each do |label, source|
          value = if source.is_a?(::Proc)
                    BASIC_EXEC.bind_call(obj, &source)
                  else
                    BASIC_EVAL.bind_call(obj, "defined?(#{source}) ? (#{source}) : ::ActiveSupport::Inspect::UNDEF")
                  end
          if label.is_a?(::Integer)
            attribute_values.update(value) if value
          else
            attribute_values[label] = value unless UNDEF == value
          end
        end

        return false if attribute_values.empty?

        q.text opener if opener

        q.group(1) do
          q.breakable(opener ? "" : " ")

          first = true
          attribute_values.each do |attr, value|
            q.group do
              if first
                first = false
              else
                q.breakable
              end
              q.text attr
              q.text "="
              q.group(1) do
                q.breakable ""
                q.pp(value)
              end
            end
          end
        end

        true
      end

      def pretty_label_segment(q, content, cycle)
        case content
        when ::Array
          q.group do
            first = true
            content.each do |el|
              if first
                first = false
              else
                q.breakable
              end
              pretty_label_segment(q, el, cycle)
            end
          end
        when ::String
          q.text content
        when ::Proc
          if cycle
            q.text "..."
          else
            content.call(q)
          end
        when ::Numeric, ::Symbol, ::TrueClass, ::FalseClass, ::NilClass
          q.pp content
        else
          if cycle
            q.text "..."
          else
            q.pp content
          end
        end
      end

      def pretty_label(q, opener, obj, cycle)
        if @label && label_content = BASIC_EXEC.bind_call(obj, &@label)
          q.text opener if opener

          q.group(1) do
            q.breakable(opener ? "" : " ")

            pretty_label_segment(q, label_content, cycle)
          end

          true
        end
      end

      # Returns three values:
      #  * leader -- the first part of the result, which will always be
      #    present.
      #  * opener -- the (optional) opening bracket to insert before the
      #    first "detail" element, if one is present.
      #  * closer -- the last part of the result, which will be included
      #    if opener was used (meaning there were details present), _or_
      #    if opener was nil (indicating that leader had already created
      #    visual nesting).
      #
      # The leader is typically a class or module name, decorated to
      # distinguish instances from direct references.
      #
      # For example, for an instance of MyClass:
      # => ["#<MyClass:0x01234567", nil, ">"]
      #
      # For the class itself:
      # => ["MyClass", "(", ")"]
      #
      #
      # The opener is passed through subsequent calls to detail methods,
      # and set to nil when they return true, indicating that they wrote
      # content (and thus consumed and wrote the opener).
      def pretty_identifier_parts(obj)
        if ::Module === obj && (own_name = MODULE_NAME.bind_call(obj)) && !own_name.start_with?("#<")
          # We are a permanently-named constant

          [own_name, "(", ")"]
        else
          klass = KERNEL_CLASS.bind_call(obj)
          leader =
            case @id
            when nil, false
              "#<#{MODULE_NAME.bind_call(klass) || MODULE_TO_S.bind_call(klass)}"
            when true
              s =
                if ::Module === obj
                  MODULE_TO_S.bind_call(obj)
                else
                  KERNEL_TO_S.bind_call(obj)
                end
              s.chomp!(">")
              s
            when :__id__, :object_id
              "#<#{MODULE_NAME.bind_call(klass)}:0x#{BASIC_ID.bind_call(obj).to_s(16)}"
            else
              "#<#{MODULE_NAME.bind_call(klass)}:#{BASIC_EXEC.bind_call(obj, &@id)}"
            end

          [leader, nil, ">"]
        end
      end

    include ActiveSupport::Inspect() { "#{source_location.path}:#{source_location.lineno}".inspect }
    ToString.include ActiveSupport::Inspect()
  end
end
