module ActionDispatch
  module Routing # :nodoc:
    class Route # :nodoc:
      class Formatter # :nodoc:
        REGEXP = %r{ \(? (?<optional>\/\w+)? (?<separator>[\/\.]+)? (?<sigil>[:\*])? (?<name>\w+) \)* }x.freeze

        class << self
          def format(path, options)
            path.string.gsub(REGEXP) do
              separator = $~['separator'] || ''
              optional  = $~['optional'] || ''
              sigil     = $~['sigil']
              name      = $~['name']
              value     = sigil ? options[name.to_sym] : name

              "#{optional}#{separator}#{Router::Utils.escape_path(value)}" if value
            end
          end
        end
      end
    end
  end
end
