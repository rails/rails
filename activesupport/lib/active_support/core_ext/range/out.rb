class Range
  after_initialize :set_not_out

  def out!
    @out = true
  end

  def out?
    @out
  end

  private

  def set_not_out
    @out = false
  end
end
