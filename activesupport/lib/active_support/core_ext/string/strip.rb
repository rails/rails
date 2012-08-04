require 'active_support/core_ext/object/try'

class String
  # Strips indentation in heredocs.
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
  # Technically, it looks for the least indented line in the whole string, and removes
  # that amount of leading whitespace.
  #
  # Use strip_heredoc(2) if you want the result to be preceded by 2 spaces. For instance, if you want to
  # insert something in a place that already has two spaces indent, like config/environments/production.rb
  #
  def strip_heredoc(with_indent = 0)
    indent = scan(/^[ \t]*(?=\S)/).min.try(:size) || 0
    gsub(/^[ \t]{#{indent}}/, ' ' * with_indent)
  end
end
