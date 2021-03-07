# frozen_string_literal: true

class String
  # Extract an Array of words from the String, split by spacing of all sizes
  #
  # Examples ===
  #
  # "Hello, world!".words # => ["Hello", "world"]
  # <<~TEXT.words         # => ["A", "sentence", "with", "many", "lines", "and", "words"]
  #   A sentence
  #   with many
  #   lines
  #     and words".
  # TEXT
  def words
    words = gsub(/[[:punct:]]/, "").split(/\s+/)

    words.reject!(&:empty?)

    words
  end
end

class NilClass
  # Returns an empty Array
  def words
    []
  end
end
