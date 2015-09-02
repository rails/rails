%w(
  .ruby-version .rbenv-vars
  tmp/caching.txt tmp/restart.txt
).each { |path| Spring.watch path }
