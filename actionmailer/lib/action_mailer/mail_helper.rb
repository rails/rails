module ActionMailer
  module MailHelper
    # Uses Text::Format to take the text and format it, indented two spaces for
    # each line, and wrapped at 72 columns.
    def block_format(text)
      begin
        require 'text/format'
      rescue LoadError => e
        $stderr.puts "You don't have text-format installed in your application. Please add it to your Gemfile and run bundle install"
        raise e
      end unless defined?(Text::Format)

      formatted = text.split(/\n\r\n/).collect { |paragraph|
        Text::Format.new(
          :columns => 72, :first_indent => 2, :body_indent => 2, :text => paragraph
        ).format
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
  end
end
