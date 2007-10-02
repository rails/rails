class BigDecimal #:nodoc:
  alias :_original_to_s :to_s
  def to_s(format="F")
    _original_to_s(format)
  end
end
