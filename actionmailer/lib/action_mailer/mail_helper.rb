# frozen_string_literal: true

module ActionMailer
  # Provides helper methods for ActionMailer::Base that can be used for easily
  # formatting messages, accessing mailer or message instances, and the
  # attachments list.
  module MailHelper
    # Take the text and format it, indented two spaces for each line, and
    # wrapped at 72 columns:
    #
    #   text = <<-TEXT
    #     This is
    #     the      paragraph.
    #
    #     * item1 * item2
    #   TEXT
    #
    #   block_format text
    #   # => "  This is the paragraph.\n\n  * item1\n  * item2\n"
    def block_format(text)
      formatted = text.split(/\n\r?\n/).collect { |paragraph|
        format_paragraph(paragraph)
      }.join("\n\n")

      # Make list points stand on their own line
      formatted.gsub!(/[ ]*([*]+) ([^*]*)/) { "  #{$1} #{$2.strip}\n" }
      formatted.gsub!(/[ ]*([#]+) ([^#]*)/) { "  #{$1} #{$2.strip}\n" }

      formatted
    end

    # Access the mailer instance.
    def mailer
      @_controller
    end

    # Access the message instance.
    def message
      @_message
    end

    # Access the message attachments list.
    def attachments
      mailer.attachments
    end

    # Returns +text+ wrapped at +len+ columns and indented +indent+ spaces.
    # By default column length +len+ equals 72 characters and indent
    # +indent+ equal two spaces.
    #
    #   my_text = 'Here is a sample text with more than 40 characters'
    #
    #   format_paragraph(my_text, 25, 4)
    #   # => "    Here is a sample text with\n    more than 40 characters"
    def format_paragraph(text, len = 72, indent = 2)
      sentences = [[]]
      space = " "
      new_line = "\n"
      indentation = " " * indent

      text.split.each do |word|
        if sentences.first.any? && (sentences.last + [word]).join(space).length > len
          sentences << [word]
        else
          sentences.last << word
        end
      end

      sentences.map! { |sentence| "#{indentation}#{sentence.join(space)}" }.join(new_line)
    end
  end
end
