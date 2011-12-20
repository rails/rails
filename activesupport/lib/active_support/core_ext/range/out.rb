class Range
  after_initialize :in!

  def out!
    @out = true
  end

  def out?
    @out
  end

  def in!
    @out = false
  end
end
