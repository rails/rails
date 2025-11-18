# frozen_string_literal: true

require "strscan"

class String
  # Strips indentation in heredocs.
  #
  # Note that since Ruby 2.3, heredocs can directly created with their indentation striped
  # by using the <tt><<~</tt> syntax instead of <tt><<-</tt>.
  # Hence the strip_heredoc method is rarely useful nowadays.
  #
  # For example in
  #
  #   if options[:usage]
  #     puts <<-USAGE.strip_heredoc
  #       This command does such and such.
  #
  #       Supported options are:
  #         -h         This message
  #         ...
  #     USAGE
  #   end
  #
  # the user would see the usage message aligned against the left margin.
  #
  # Technically, it looks for the least indented non-empty line
  # in the whole string, and removes that amount of leading whitespace.
  def strip_heredoc
    scanner = StringScanner.new("")

    min_indent_len = nil
    lines = self.lines

    lines.each do |line|
      scanner.string = line
      indent_len = scanner.skip(/[ \t]*/)

      next unless scanner.match?(/[^\r\n]/)

      min_indent_len = indent_len if indent_len < (min_indent_len || Float::INFINITY)
    end


    if min_indent_len.nil? || min_indent_len.zero?
      return frozen? ? self : dup
    end

    lines.each do |line|
      line[0, min_indent_len] = "" unless line == "\n"
    end

    result = lines.join

    result.freeze if frozen?
    result
  end
end
