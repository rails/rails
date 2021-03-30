# frozen_string_literal: true

require "active_support/core_ext/module/concerning"

module Kernel
  module_function

  # A shortcut to define a toplevel concern, not within a module.
  #
  # See Module::Concerning for more.
  def concern(topic, &module_definition)
    ActiveSupport::Deprecation.warn(<<~EOM)
      Defining toplevel concern via Kernel#concern is deprecated.
      Please define a module and extend ActiveSupport::Concern instead.

      For example, instead of:

      concern :Foo do
        ...
      end

      Define the module manually:

      module Foo
        extend ActiveSupport::Concern
        ...
      end
    EOM

    Object.concern topic, &module_definition
  end
end
