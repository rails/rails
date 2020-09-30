*   Expose how we render the HTML _surrounding_ rich text content as an
    extensible `layouts/action_view/contents/_content.html.erb` template to
    encourage user-land customizations, while retaining private API control over how
    the rich text itself is rendered by `action_text/contents/_content.html.erb`
    partial.

    *Sean Doyle*

*   Add `with_all_rich_text` method to eager load all rich text associations on a model at once.

    *Matt Swanson*, *DHH*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actiontext/CHANGELOG.md) for previous changes.
