require 'rails/commands/command'

module Rails
  module Commands
    class Docs < Command
      rake_delegate 'doc:app', 'doc:guides', 'doc:rails'

      set_banner :doc_app, ''
      set_banner :doc_guides, ''
      set_banner :doc_rails, ''
    end
  end
end
