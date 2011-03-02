module ActionMailer
  module MailHelper
    # Uses Text::Format to take the text and format it, indented two spaces for
    # each line, and wrapped at 72 columns.
    def block_format(text)
      formatted = text.split(/\n\r\n/).collect { |paragraph|
        simple_format(paragraph)
      }.join("\n")

      # Make list points stand on their own line
      formatted.gsub!(/[ ]*([*]+) ([^*]*)/) { |s| "  #{$1} #{$2.strip}\n" }
      formatted.gsub!(/[ ]*([#]+) ([^#]*)/) { |s| "  #{$1} #{$2.strip}\n" }

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
      @_message.attachments
    end

    private
    def simple_format(text, len = 72, indent = 2)
      sentences = [[]]

      text.split.each do |word|
        if (sentences.last + [word]).join(' ').length > len
          sentences << [word]
        else
          sentences.last << word
        end
      end

      sentences.map { |sentence|
        "#{" " * indent}#{sentence.join(' ')}"
      }.join "\n"
    end
  end
end
