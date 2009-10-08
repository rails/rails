class String
  def html_safe?
    defined?(@_rails_html_safe) && @_rails_html_safe
  end

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
    if html_safe? && also_html_safe?(other)
      result.html_safe!
    else
      result
    end
  end
  
  alias original_concat <<
  def <<(other)
    result = original_concat(other)
    unless html_safe? && also_html_safe?(other)
      @_rails_html_safe = false
    end
    result
  end
  
  def concat(other)
    self << other
  end
  
  private
    def also_html_safe?(other)
      other.respond_to?(:html_safe?) && other.html_safe?
    end
  
end