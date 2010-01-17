module ActiveSupport
  FrozenObjectError = RUBY_VERSION < '1.9' ? TypeError : RuntimeError
end
