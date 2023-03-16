# frozen_string_literal: true

class Hash
  # Returns a new hash from nested hash.
  #
  #   hash = { a: true, b: { c: { d: 1 } } }
  #
  #   hash.flatten_hash # => { a: true, d: 1 } }
  #
  #   hash = { a: true, b: { c: 1, d: { e: "saleh" } } }
  #
  #   hash.flatten_hash # => { a: true, c: 1, e: "saleh" } }
  #
  #   hash = { a: true, b: { c: 1, d: { e: { f: "salem" } } } }
  #
  #   hash.flatten_hash # => { a: true, c: 1, f: "salem" } }
  #
  def flatten_hash
    new_hash = {}
    self.each do |key, value|
      if value.is_a?(Hash)
        new_hash.merge!(value.flatten_hash)
      else
        new_hash[key.to_sym] = value
      end
    end
    new_hash
  end
end
