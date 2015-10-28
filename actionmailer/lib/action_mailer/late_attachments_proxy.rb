module ActionMailer
  class LateAttachmentsProxy < SimpleDelegator #:nodoc:
    def inline; _raise_error end

    def []=(_name, _content); _raise_error end

    private

      def _raise_error
        fail "Can't add attachments after `mail` was called.\n" \
             "Make sure to use `attachments[]=` before calling `mail`."
      end
  end
end
