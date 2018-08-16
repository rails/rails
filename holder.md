
The guide is revamped in this version.

* There are no more references to `form_for` or `form_tag` except for the footnote that points to older documentation.

* All functionality that is now utilized with `form_with` has been updated

* There is a note about the `remote: true` default and `local: true` option

* There is a note about the ability for users to include non-attribute inputs on form builder now

* Notes that `class` and `id` are no longer required in HTML hash.

Using form_with
---------------

Both of the interfaces for `form_tag` and `form_with` are combined in `form_with`; which
can generate form tags based on URLs, scopes, or models.

Using just a URL:

```html+erb
<%= form_with url: posts_path do |form| %>
  <%= form.text_field :title %>
<% end %>

<%# Will generate %>

<form action="/posts" method="post" data-remote="true">
  <input type="text" name="title">
</form>
```

Adding a scope prefixes the input field names:

```html+erb
<%= form_with scope: :post, url: posts_path do |form| %>
  <%= form.text_field :title %>
<% end %>

<%# Will generate %>

<form action="/posts" method="post" data-remote="true">
  <input type="text" name="post[title]">
</form>
```

Using a model infers both the URL and scope:

```html+erb
<%= form_with model: Post.new do |form| %>
  <%= form.text_field :title %>
<% end %>

<%# Will generate %>

<form action="/posts" method="post" data-remote="true">
  <input type="text" name="post[title]">
</form>
```

An existing model makes an update form and fills out field values:

```html+erb
<%= form_with model: Post.first do |form| %>
  <%= form.text_field :title %>
<% end %>

<%# Will generate %>

<form action="/posts/1" method="post" data-remote="true">
  <input type="hidden" name="_method" value="patch">
  <input type="text" name="post[title]" value="<the title of the post>">
</form>
```

However, the fields don't have to correspond to model attributes:

```erb
<%= form_with model: Cat.new do |form| %>
  <%= form.text_field :cats_dont_have_gills %>
  <%= form.text_field :but_in_forms_they_can %>
<% end %>
```

For namespaced routes, like `admin_post_url`:

```erb
  <%= form_with(model: [ :admin, @post ]) do |form| %>
    ...
  <% end %>
```

For resources with nested associations defined:

```erb
  <%= form_with(model: [ @document, Comment.new ]) do |form| %>
    ...
  <% end %>
```

### Mixing with other form helpers

While `form_with` uses a FormBuilder object it's possible to mix and
match the stand-alone FormHelper methods and methods
from FormTagHelper:

```erb
  <%= form_with scope: :person do |form| %>
    <%= form.text_field :first_name %>
    <%= form.text_field :last_name %>

    <%= text_area :person, :biography %>
    <%= check_box_tag "person[admin]", "1", @person.company.admin? %>

    <%= form.submit %>
  <% end %>
```

### `form_with` options

* `:url` - The URL the form submits to. Akin to values passed to
  +url_for+ or +link_to+. For example, you may use a named route
  directly. When a `:scope` is passed without a `:url` the
  form just submits to the current URL.
* `:method` - The method to use when submitting the form, usually
  either "get" or "post". If "patch", "put", "delete", or another verb
  is used, a hidden input named `_method` is added to
  simulate the verb over post.
* `:format` - The format of the route the form submits to.
  Useful when submitting to another resource type, like `:json`.
  Skipped if a `:url` is passed.
* `:scope` - The scope to prefix input field names with and
  thereby how the submitted parameters are grouped in controllers.
* `:model` - A model object to infer the `:url` and
  `:scope` by, plus fill out input field values.
  So if a +title+ attribute is set to "Ahoy!" then a +title+ input
  field's value would be "Ahoy!".
  If the model is a new record a create form is generated, if an
  existing record, however, an update form is generated.
  Pass `:scope` or `:url` to override the defaults.
  E.g. turn `params[:post]` into `params[:article]`.
* `:authenticity_token` - Authenticity token to use in the form.
  Override with a custom authenticity token or pass `false` to
  skip the authenticity token field altogether.
  Useful when submitting to an external resource like a payment gateway
  that might limit the valid fields.
  Remote forms may omit the embedded authenticity token by setting
  `config.action_view.embed_authenticity_token_in_remote_forms = false`.
  This is helpful when fragment-caching the form. Remote forms
  get the authenticity token from the `meta` tag, so embedding is
  unnecessary unless you support browsers without JavaScript.
* `:local` - By default form submits are remote and unobtrusive XHRs.
  Disable remote submits with `local: true`.
* `:skip_enforcing_utf8` - If set to true, a hidden input with name
  utf8 is not output.
* `:builder` - Override the object used to build the form.
* `:id` - Optional HTML id attribute.
* `:class` - Optional HTML class attribute.
* `:data` - Optional HTML data attributes.
* `:html` - Other optional HTML attributes for the form tag.
