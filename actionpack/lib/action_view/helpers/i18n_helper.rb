module ActionView
  module Helpers 
    module I18nHelper
      def translate(*args)
        # inserts the locale or current request locale to the argument list if no locale 
        # has been passed or the locale has been passed as part of the options hash
        options = args.extract_options!
        if args.size != 2
          locale = options.delete :locale
          locale ||= request.locale if respond_to? :request
          args << locale if locale
        end
        args << options unless options.empty?
        I18n.translate *args
      end
      alias :t :translate
    end
  end
end