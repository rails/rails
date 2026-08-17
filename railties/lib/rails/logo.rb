# frozen_string_literal: true

# :markup: markdown

module Rails
  module Logo # :nodoc:
    LINES = %w[⠀⢀⠀⢡⣶⣿⠟⡛⠢ ⠠⠀⣰⣿⣿⠁⠄⠀⠀ ⠶⢠⣿⣿⣿⠰⠆⠀⠀ ⠶⢸⣿⣿⣿⡄⠰⠆⠀].freeze

    def self.lines_for(io)
      (io.external_encoding || Encoding.default_external) == Encoding::UTF_8 ? LINES : nil
    end

    def self.beside(info_lines, io:)
      lines = lines_for(io)
      return info_lines.join("\n") unless lines

      lines.zip(info_lines).map { |logo, info| "#{yield logo}  #{info}".rstrip }.join("\n")
    end
  end
end
