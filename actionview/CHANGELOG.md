*   Add `f.datalist` to `FormBuilder`

    Example:

        <%= form_with model: @post do |f| %>
           <%# Wire the input to the datalist using the same derived id: %>
           <%= f.text_field :country, list: f.field_id(:country, :datalist) %>
           <%= f.datalist  :country, ["Argentina", "Brazil", "Chile"] %>
        <% end %>

          Produces:
          <input list="post_country_datalist" type="text"
                 name="post[country]" id="post_country" />
          <datalist id="post_country_datalist">
            <option value="Argentina">Argentina</option>
            <option value="Brazil">Brazil</option>
            <option value="Chile">Chile</option>
          </datalist>

      *Tahsin Hasan*

*   Add `datalist_tag` to create `datalist` form elements.

    Example:

        datalist_tag('countries_datalist', ['Argentina', ['Brazil', { class: 'brazilian_option' }],
                     ['Chile', 'CL', { disabled: true }]], { class: 'sa-countries-sample' })
        => <datalist id="countries_datalist" class="sa-countries-sample">
             <option value="Argentina">Argentina</option>
             <option value="Brazil" class="brazilian_option">Brazil</option>
             <option value="CL" disabled="disabled">Chile</option>
           </datalist>

    *Willian Gustavo Veiga*

*   Render `Hash` and keyword options as dasherized HTML attributes

    ```ruby
    tag.button "POST to /clicked", hx: { post: "/clicked", swap: :outerHTML, data: { json: true } }

    # => <button hx-post="/clicked" hx-swap="outerHTML" hx-data="{&quot;json&quot;:true}">POST to /clicked</button>
    ```

    *Sean Doyle*

*   `ViewReloader#deactivate` removes the `file_system_resolver_hooks` callback
    so forked processes that clear reloaders no longer trigger filesystem scans
    on every `prepend_view_path`.

    *Dave Ariens*

*   Defer the View watcher build until view paths are actually registered.

    *Hugo Vacher*

*   Skip blank attribute names in tag helpers to avoid generating invalid HTML.

    *Mike Dalessio*

*   Fix tag parameter content being overwritten instead of combined with tag block content.
    Before `tag.div("Hello ") { "World" }` would just return `<div>World</div>`, now it returns `<div>Hello World</div>`.

    *DHH*

*   Add ability to pass a block when rendering collection. The block will be executed for each rendered element in the collection.

    *Vincent Robert*

*   Add `key:` and `expires_in:` options under `cached:` to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionview/CHANGELOG.md) for previous changes.
