class Array
  # Returns an unique array based on the criteria given as a +Proc+.
  #
  #   [1, 2, 3, 4].uniq_by { |i| i.odd? } # => [1, 2]
  #
  def uniq_by(&block)
    ActiveSupport::Deprecation.warn "uniq_by " \
      "is deprecated. Use Array#uniq instead", caller
    uniq(&block)
  end

  # Same as uniq_by, but modifies self.
  def uniq_by!(&block)
    ActiveSupport::Deprecation.warn "uniq_by! " \
      "is deprecated. Use Array#uniq! instead", caller
    uniq!(&block)
  end
end
