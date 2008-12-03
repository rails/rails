module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module CGI #:nodoc:
      module EscapeSkippingSlashes #:nodoc:
        if RUBY_VERSION >= '1.9'
          def escape_skipping_slashes(str)
            str = str.join('/') if str.respond_to? :join
            str.gsub(/([^ \/a-zA-Z0-9_.-])/n) do
              "%#{$1.unpack('H2' * $1.bytesize).join('%').upcase}"
            end.tr(' ', '+')
          end
        else
          def escape_skipping_slashes(str)
            str = str.join('/') if str.respond_to? :join
            str.gsub(/([^ \/a-zA-Z0-9_.-])/n) do
              "%#{$1.unpack('H2').first.upcase}"
            end.tr(' ', '+')
          end
        end
      end
    end
  end
end
