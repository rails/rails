*   Add template precompilation support.

    View templates can now be eagerly compiled at boot time when
    `config.action_view.precompile_templates = true` (enabled by default in
    `load_defaults "8.2"`) and `config.eager_load` is also `true`. This
    improves cold render times and allows more memory to be shared via
    copy-on-write on forking web servers.

    The precompiler scans view templates, controllers, and helpers for
    `render` calls, detects implicit controller action renders, and supports
    engine view paths.

    Additional directories can be scanned for `render` calls using
    `config.action_view.precompile_additional_paths`.

    Emits a `precompile_templates.action_view` notification with `:count`
    in the payload.

    Based on the `actionview_precompiler` gem by John Hawthorn. GitHub has
    used this optimization for over 5 years, saving an estimated ~500MB of
    memory per container (each with 11 forked workers) for ~7,000 templates.

    *Joel Hawksley*, *John Hawthorn*

*   Fix `ActionView::TestCase#render` to reset `rendered`.
    The behavior was changed when memoization was added in #51093. Now it once again conforms to the documentation.

    *Jeroen Versteeg*

*   Fix `FormBuilder#to_partial_path` returning `nil` for subclasses whose
    name does not end in `Builder`.

    *Kenta Ishizaki*

*   Fix `collection_radio_buttons` and `collection_check_boxes` generating
    a label `for` attribute that does not match the input `id` when a
    collection value is `nil`.

    *Kenta Ishizaki*

*   Pass render options and block to calls to `#render_in`

    ```ruby
    class Greeting
      def render_in(view_context, **)
        if block_given?
          view_context.render(html: yield)
        else
          view_context.render(inline: <<~ERB.strip, **)
            Hello <%= local_assigns[:name] || "World" %>
          ERB
        end
      end
    end

    render(Greeting.new)                                        # => "Hello, World"
    render(Greeting.new, name: "Local")                         # => "Hello, Local"
    render(renderable: Greeting.new, locals: { name: "Local" }) # => "Hello, Local"
    render(Greeting.new) { "Hello, Block" }                     # => "Hello, Block"
    ```

    *Sean Doyle*

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
