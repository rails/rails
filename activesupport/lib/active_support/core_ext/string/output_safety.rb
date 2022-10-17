# frozen_string_literal: true

require "erb"
require "active_support/core_ext/module/redefine_method"
require "active_support/core_ext/erb/util"
require "active_support/multibyte/unicode"

class Object
  def html_safe?
    false
  end
end

class Numeric
  def html_safe?
    true
  end
end

module ActiveSupport # :nodoc:
  class SafeBuffer < String
    UNSAFE_STRING_METHODS = %w(
      capitalize chomp chop delete delete_prefix delete_suffix
      downcase lstrip next reverse rstrip scrub slice squeeze strip
      succ swapcase tr tr_s unicode_normalize upcase
    )

    UNSAFE_STRING_METHODS_WITH_BACKREF = %w(gsub sub)

    alias_method :original_concat, :concat
    private :original_concat

    # Raised when ActiveSupport::SafeBuffer#safe_concat is called on unsafe buffers.
    class SafeConcatError < StandardError
      def initialize
        super "Could not concatenate to the buffer because it is not HTML safe."
      end
    end

    def [](*args)
      to_str[*args]
    end

    def safe_concat(value)
      raise SafeConcatError unless html_safe?
      original_concat(value)
    end

    def initialize(str = "")
      @html_safe = true
      super
    end

    def initialize_copy(other)
      super
      @html_safe = other.html_safe?
    end

    def clone_empty
      return self.class.new if html_safe?

      self[0, 0]
    end

    def concat(value)
      unless value.nil?
        super(implicit_html_escape_interpolated_argument(value))
      end
      self
    end
    alias << concat

    def insert(index, value)
      super(index, implicit_html_escape_interpolated_argument(value))
    end

    def prepend(value)
      super(implicit_html_escape_interpolated_argument(value))
    end

    def replace(value)
      super(implicit_html_escape_interpolated_argument(value))
    end

    def []=(*args)
      if args.length == 3
        super(args[0], args[1], implicit_html_escape_interpolated_argument(args[2]))
      else
        super(args[0], implicit_html_escape_interpolated_argument(args[1]))
      end
    end

    def +(other)
      dup.concat(other)
    end

    def *(*)
      new_string = super
      new_safe_buffer = new_string.is_a?(SafeBuffer) ? new_string : SafeBuffer.new(new_string)
      new_safe_buffer.instance_variable_set(:@html_safe, @html_safe)
      new_safe_buffer
    end

    def %(args)
      case args
      when Hash
        escaped_args = args.transform_values { |arg| explicit_html_escape_interpolated_argument(arg) }
      else
        escaped_args = Array(args).map { |arg| explicit_html_escape_interpolated_argument(arg) }
      end

      self.class.new(super(escaped_args))
    end

    attr_reader :html_safe
    alias_method :html_safe?, :html_safe
    remove_method :html_safe

    def to_s
      self
    end

    def to_param
      to_str
    end

    def encode_with(coder)
      coder.represent_object nil, to_str
    end

    UNSAFE_STRING_METHODS.each do |unsafe_method|
      if unsafe_method.respond_to?(unsafe_method)
        class_eval <<-EOT, __FILE__, __LINE__ + 1
          def #{unsafe_method}(*args, &block)       # def capitalize(*args, &block)
            to_str.#{unsafe_method}(*args, &block)  #   to_str.capitalize(*args, &block)
          end                                       # end

          def #{unsafe_method}!(*args)              # def capitalize!(*args)
            @html_safe = false                      #   @html_safe = false
            super                                   #   super
          end                                       # end
        EOT
      end
    end

    UNSAFE_STRING_METHODS_WITH_BACKREF.each do |unsafe_method|
      class_eval <<-EOT, __FILE__, __LINE__ + 1
        def #{unsafe_method}(*args, &block)             # def gsub(*args, &block)
          if block                                      #   if block
            to_str.#{unsafe_method}(*args) { |*params|  #     to_str.gsub(*args) { |*params|
              set_block_back_references(block, $~)      #       set_block_back_references(block, $~)
              block.call(*params)                       #       block.call(*params)
            }                                           #     }
          else                                          #   else
            to_str.#{unsafe_method}(*args)              #     to_str.gsub(*args)
          end                                           #   end
        end                                             # end

        def #{unsafe_method}!(*args, &block)            # def gsub!(*args, &block)
          @html_safe = false                            #   @html_safe = false
          if block                                      #   if block
            super(*args) { |*params|                    #     super(*args) { |*params|
              set_block_back_references(block, $~)      #       set_block_back_references(block, $~)
              block.call(*params)                       #       block.call(*params)
            }                                           #     }
          else                                          #   else
            super                                       #     super
          end                                           #   end
        end                                             # end
      EOT
    end

    private
      def explicit_html_escape_interpolated_argument(arg)
        (!html_safe? || arg.html_safe?) ? arg : CGI.escapeHTML(arg.to_s)
      end

      def implicit_html_escape_interpolated_argument(arg)
        if !html_safe? || arg.html_safe?
          arg
        else
          arg_string = begin
            arg.to_str
          rescue NoMethodError => error
            if error.name == :to_str
              str = arg.to_s
              ActiveSupport::Deprecation.warn <<~MSG.squish
                Implicit conversion of #{arg.class} into String by ActiveSupport::SafeBuffer
                is deprecated and will be removed in Rails 7.1.
                You must explicitly cast it to a String.
              MSG
              str
            else
              raise
            end
          end
          CGI.escapeHTML(arg_string)
        end
      end

      def set_block_back_references(block, match_data)
        block.binding.eval("proc { |m| $~ = m }").call(match_data)
      rescue ArgumentError
        # Can't create binding from C level Proc
      end
  end
end

class String
  # Marks a string as trusted safe. It will be inserted into HTML with no
  # additional escaping performed. It is your responsibility to ensure that the
  # string contains no malicious content. This method is equivalent to the
  # +raw+ helper in views. It is recommended that you use +sanitize+ instead of
  # this method. It should never be called on user input.
  def html_safe
    ActiveSupport::SafeBuffer.new(self)
  end
end
