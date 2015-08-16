require 'rails/commands/command'

module Rails
  module Commands
    class CacheDigests < Command
      rake_delegate 'cache_digests:dependencies', 
        'cache_digests:nested_dependencies'

      set_banner :cache_digests_dependencies,
        'Lookup first-level dependencies for TEMPLATE (like messages/show or comments/_comment.html)'
      set_banner :cache_digests_nested_dependencies, 
        'Lookup nested dependencies for TEMPLATE (like messages/show or comments/_comment.html)'
    end
  end
end
