module ActionMailer
  module Utils #:nodoc:
    def normalize_new_lines(text)
      text.to_s.gsub(/\r\n?/, "\n")
    end
  end
end
