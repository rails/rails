require "rbconfig"

module ActiveSupport
  module Multibyte
    module Unicode
      module Backend # :nodoc:
        extend ActiveSupport::Autoload

        autoload :Native
        autoload :NonNative

        class << self
          def lookup(name)
            case name
            when :native
              if support_native_unicode_implementation?
                Native
              else
                raise NotImplementedError, ":native backend requires Ruby 2.4 or newer."
              end
            when :non_native
              NonNative
            else
              raise ArgumentError, "backend name must be `:native` or `:non_native`"
            end
          end

          def support_native_unicode_implementation?
            RbConfig::CONFIG.key?("UNICODE_VERSION")
          end
        end
      end
    end
  end
end
