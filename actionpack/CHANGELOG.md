*   Allow variants to be set through the URL.

    request.variant can be set from URL. For example, accessing
    http://example.com/posts.html+partial sets `request.variant = [:partial]`
    automatically. `:variant` is tied to `:format` like `(.:format(+:variant))`.

    *Hong ChulJu*, *Mohit Natoo*, *Mark Godwin*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionpack/CHANGELOG.md) for previous changes.
