module ActionMailer
  class NullMail #:nodoc:
    def body; '' end

    def header; {} end

    def respond_to?(_string, _include_all = false)
      true
    end

    def method_missing(*)
      nil
    end
  end
end
