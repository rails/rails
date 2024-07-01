*   Add a disabled configuration `rename_csp_helper_nonce_attribute` to rename the csp_meta_tag helper nonce attribute name
    If enabled, it renames the `content` attribute to `nonce` to avoid certain kinds of value exfiltration attacks.

    ```
    app.config.action_view.rename_csp_helper_nonce_attribute = true
    <%= csp_meta_tag %>
    # renders
    <meta name="csp-nonce" nonce="..." />
    # instead of
    <meta name="csp-nonce" content="..." />
    ```

    *Niklas Häusele*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.
