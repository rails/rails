*   Only reset the `connection_specification_name` in `remove_connection` is there's one connection.

    Previously, `#remove_connection` would always set the `connection_specification_name` to `nil` if it found a matching pool. This caused the connection to fall back to the parent class because it will adopt the `connection_specification_name` of the parent. When an application has multiple roles or shards, Active Record should not set the `connection_specification_name` to `nil` unless it's the only remaining pool. To fix this, Active Record now checks if the pool size for a given connection name is equal to 1. If it is the `connection_specification_name` is set to `nil`, otherwise the name is retained. In both cases the pool for the matching shard and role is removed.

    *Eileen M. Uchitelle*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
