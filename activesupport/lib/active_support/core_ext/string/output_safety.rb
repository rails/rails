require 'erb'

class ERB
  undef :set_eoutvar
  def set_eoutvar(compiler, eoutvar = '_erbout')
    compiler.put_cmd = "#{eoutvar}.safe_concat"
    compiler.insert_cmd = "#{eoutvar}.safe_concat"

    cmd = []
    cmd.push "#{eoutvar} = ActiveSupport::SafeBuffer.new"

    compiler.pre_cmd = cmd

    cmd = []
    cmd.push(eoutvar)

    compiler.post_cmd = cmd
  end

  module Util
    HTML_ESCAPE = { '&' => '&amp;',  '>' => '&gt;',   '<' => '&lt;', '"' => '&quot;' }
    JSON_ESCAPE = { '&' => '\u0026', '>' => '\u003E', '<' => '\u003C' }

    # A utility method for escaping HTML tag characters.
    # This method is also aliased as <tt>h</tt>.
    #
    # In your ERb templates, use this method to escape any unsafe content. For example:
    #   <%=h @person.name %>
    #
    # ==== Example:
    #   puts html_escape("is a > 0 & a < 10?")
    #   # => is a &gt; 0 &amp; a &lt; 10?
    def html_escape(s)
      s = s.to_s
      if s.html_safe?
        s
      else
        s.gsub(/[&"><]/) { |special| HTML_ESCAPE[special] }.html_safe
      end
    end

    undef :h
    alias h html_escape

    module_function :html_escape
    module_function :h

    # A utility method for escaping HTML entities in JSON strings.
    # This method is also aliased as <tt>j</tt>.
    #
    # In your ERb templates, use this method to escape any HTML entities:
    #   <%=j @person.to_json %>
    #
    # ==== Example:
    #   puts json_escape("is a > 0 & a < 10?")
    #   # => is a \u003E 0 \u0026 a \u003C 10?
    def json_escape(s)
      s.to_s.gsub(/[&"><]/) { |special| JSON_ESCAPE[special] }
    end

    alias j json_escape
    module_function :j
    module_function :json_escape
  end
end

class Object
  def html_safe?
    false
  end
end

class Fixnum
  def html_safe?
    true
  end
end

module ActiveSupport #:nodoc:
  class SafeBuffer < String
    alias safe_concat concat

    def concat(value)
      if value.html_safe?
        super(value)
      else
        super(ERB::Util.h(value))
      end
    end

    def +(other)
      dup.concat(other)
    end

    def <<(value)
      self.concat(value)
    end

    def html_safe?
      true
    end

    def html_safe
      self
    end

    def to_s
      self
    end
  end
end

class String
  alias_method :add_without_safety, :+

  def html_safe
    ActiveSupport::SafeBuffer.new(self)
  end

  def html_safe?
    defined?(@_rails_html_safe) && @_rails_html_safe
  end

  def html_safe!
    ActiveSupport::Deprecation.warn("Use html_safe with your strings instead of html_safe! See http://yehudakatz.com/2010/02/01/safebuffers-and-rails-3-0/ for the full story.", caller)
    @_rails_html_safe = true
    self
  end

  def add_with_safety(other)
    result = add_without_safety(other)
    if html_safe? && also_html_safe?(other)
      result.html_safe!
    else
      result
    end
  end
  alias_method :+, :add_with_safety

  def concat_with_safety(other_or_fixnum)
    result = concat_without_safety(other_or_fixnum)
    unless html_safe? && also_html_safe?(other_or_fixnum)
      @_rails_html_safe = false
    end
    result
  end
  alias_method_chain :concat, :safety
  undef_method :<<
  alias_method :<<, :concat_with_safety

  private
   def also_html_safe?(other)
     other.respond_to?(:html_safe?) && other.html_safe?
   end
end
