# Fakes out gem optional dependencies until they are fully supported by gemspec.
# Activate any optional dependencies that are available.
if defined? Gem
  begin
    gem 'builder', '~> 2.1.2'
  rescue Gem::LoadError
  end

  begin
    gem 'memcache-client', '>= 1.6.5'
  rescue Gem::LoadError
  end

  begin
    gem 'tzinfo', '~> 0.3.13'
  rescue Gem::LoadError
  end

  begin
    gem 'i18n', '~> 0.1.3'
  rescue Gem::LoadError
  end
end
