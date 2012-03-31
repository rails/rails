class Integer
  # Converts a integer into an array by default to_range includes the integer
  #
  # 5.to_range                    # => 0..5
  # 5.to_range(:exclude => true)  # => 0...5
  #
  def to_range(*args)
    options = args.extract_options!
    exclude_num = options[:exclude] || false

    exclude_num ? (0...self) : (0..self)
  end
end
