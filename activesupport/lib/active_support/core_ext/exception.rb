module ActiveSupport
  FrozenObjectError = Gem.ruby_version < '1.9' ? TypeError : RuntimeError
end

