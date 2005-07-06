module ActionMailer
  module Utils #:nodoc:
    def normalize_new_lines(text)
      text.to_s.gsub(/\r\n?/, "\n")
    end
    module_function :normalize_new_lines
  end
end
