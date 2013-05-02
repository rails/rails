*   Rails::Railtie no longer forces the Rails::Configurable module on everything
    that subclassess it. Instead, the methods from Rails::Configurable have been
    moved to class methods in Railtie and the Railtie has been made abstract.

    *John Wang*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/railties/CHANGELOG.md) for previous changes.
