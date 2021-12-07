* Move database and shard selection config options to a generator.

  Rather than generating the config options in the production.rb when applications are created, applications can now run a generator to create an initializer and uncomment / update options as needed. All multi-db configuration can be imlpemented in this initializer.

  *Eileen M. Uchitelle*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activerecord/CHANGELOG.md) for previous changes.
