# encoding: utf-8

# Stub class for the Simple backend. The actual implementation is provided by
# the backend Base class. This makes it easier to extend the Simple backend's
# behaviour by including modules. E.g.:
#
# module I18n::Backend::Pluralization
#   def pluralize(*args)
#     # extended pluralization logic
#     super
#   end
# end
#
# I18n::Backend::Simple.send(:include, I18n::Backend::Pluralization)

module I18n
  module Backend
    class Simple
      include Base
    end
  end
end
