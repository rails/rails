# frozen_string_literal: true

module Rails
  module Generators
    class SystemTestGenerator < NamedBase # :nodoc:
      hook_for :system_tests, as: :system
    end
  end
end
