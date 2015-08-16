require 'rails/commands/command'
require 'rake'

module Rails
  module Commands
    class Assets < Command
      set_banner :assets_clean, ''
      set_banner :assets_clobber, ''
      set_banner :assets_environment, ''
      set_banner :assets_precompile, ''

      rake_delegate 'assets:clean', 'assets:clobber', 'assets:environment',
        'assets:precompile'
    end
  end
end
