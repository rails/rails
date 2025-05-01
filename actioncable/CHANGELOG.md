*   `action_cable_meta_tag` uses `Rack::Request#script_name` to generate the Action Cable mount path.

    The Action Cable server route, if it is configured via `config.action_cable.mount_path`, now has
    a name, "action_cable_mount", which is used by the meta tag helper.

    *Mike Dalessio*

*   Allow setting nil as subscription connection identifier for Redis.

    *Nguyen Nguyen*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actioncable/CHANGELOG.md) for previous changes.
