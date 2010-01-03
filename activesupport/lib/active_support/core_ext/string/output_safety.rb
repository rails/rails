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

class String
  attr_accessor :_rails_html_safe
  alias html_safe? _rails_html_safe

  def html_safe!
    @_rails_html_safe = true
    self
  end

  def html_safe
    dup.html_safe!
  end

  alias original_plus +
  def +(other)
    result = original_plus(other)
    result._rails_html_safe = html_safe? && other.html_safe?
    result
  end

  alias original_concat <<
  alias safe_concat <<
  def <<(other)
    @_rails_html_safe = false unless other.html_safe?
    result = original_concat(other)
  end

  alias concat <<
end