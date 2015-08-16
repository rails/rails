module Rails
  module Commands
    class Tmp < Command
      set_banner :tmp_clear, 
        'Clear cache and socket files from tmp/ (narrow w/ tmp:cache:clear, tmp:sockets:clear)'
      set_banner :tmp_create, ''
      set_banner :tmp_sessions_clear, 
        'Clear session files from tmp/sessions/'
      set_banner :tmp_cache_clear, 
        'Clear cache files from tmp/cache/'
      set_banner :tmp_sockets_clear,
        'Clear socket files from tmp/sockets/'

      rake_delegate 'tmp:clear', 'tmp:create', 'tmp:sessions:clear', 'tmp:cache:clear', 'tmp:sockets:clear'
    end
  end
end
