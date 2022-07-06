# frozen_string_literal: true

class Hash
  # Easily build a new deep hash
  #
  #   Hash.bury(:conferences, :tracks, :sessions, :keynote, presenter: '@tenderlove', topic: 'hotwire')
  #   # => { conferences: { tracks: { sessions: { keynote: { presenter: "@tenderlove", :topic=>"hotwire" } } } } }
  #
  #   Hash.bury(:a, 0, c: 42)
  #   # => { a: { 0 => { c: 42 } } }
  #
  # Use bury with deep_merge to make modifications deep in the hash structure:
  #
  #   h1 = { a: { b: { c: { c1: 100 } } } }
  #   h1.deep_merge(Hash.bury(:a, :b, :c, c2: 200, c3: 300))
  #   # => { a: { b: { c: { c1: 100, c2: 200, c3: 300 } } } }
  def self.bury(*args, **kwargs)
    args.reverse.reduce(Hash.new.merge(**kwargs)) do |hash, arg|
      { arg => hash }
    end
  end
end
