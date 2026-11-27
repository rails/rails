# :markup: markdown
# frozen_string_literal: true

# Ruby 4.1 makes `Symbol#to_s` return the symbol's interned frozen String, the
# same object `Symbol#name` returns, instead of allocating a new String on every
# call (https://bugs.ruby-lang.org/issues/22137). Ruby 3.4 and 4.0 already warn
# when that String is mutated. Give older Rubies the 4.1 behavior so that code
# does not need to special-case Symbols to avoid the allocation.
unless :to_s.to_s.frozen?
  require "active_support/core_ext/module/redefine_method"

  class Symbol
    silence_redefinition_of_method :to_s
    alias_method :to_s, :name
  end
end
