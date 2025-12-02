*   Add `RAILS_HOST_APP_PATH` environment variable to support editor links in devcontainer/Docker environments.

    When Rails runs inside a container, file paths in error pages are container-internal paths
    that don't exist on the host machine. Setting `RAILS_HOST_APP_PATH` to the host's application
    path enables proper translation of container paths to host paths for editor links.

    Example in `.devcontainer/devcontainer.json`:

    ```json
    {
      "containerEnv": {
        "EDITOR": "code",
        "RAILS_HOST_APP_PATH": "${localWorkspaceFolder}"
      }
    }
    ```

    This allows the "open in editor" feature to work correctly when developing in containers.

    *Victor Cobos*

*   Support `text/markdown` format in `DebugExceptions` middleware.

    When `text/markdown` is requested via the Accept header, error responses
    are returned with `Content-Type: text/markdown` instead of HTML.
    The existing text templates are reused for markdown output, allowing
    CLI tools and other clients to receive byte-efficient error information.

    *Guillermo Iguaran*

*   Support dynamic `to:` and `within:` options in `rate_limit`.

    The `to:` and `within:` options now accept callables (lambdas or procs) and
    method names (as symbols), in addition to static values. This allows for
    dynamic rate limiting based on user attributes or other runtime conditions.

    ```ruby
    class APIController < ApplicationController
      rate_limit to: :max_requests, within: :time_window, by: -> { current_user.id }

      private
        def max_requests
          current_user.premium? ? 1000 : 100
        end

        def time_window
          current_user.premium? ? 1.hour : 1.minute
        end
    end
    ```

    *Murilo Duarte*

*   Define `ActionController::Parameters#deconstruct_keys` to support pattern matching

    ```ruby
    if params in { search:, page: }
      Article.search(search).limit(page)
    else
      …
    end

    case (value = params[:string_or_hash_with_nested_key])
    in String
      # do something with a String `value`…
    in { nested_key: }
      # do something with `nested_key` or `value`
    else
      # …
    end
    ```

    *Sean Doyle*

*   Submit test requests using `as: :html` with `Content-Type: x-www-form-urlencoded`

    *Sean Doyle*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionpack/CHANGELOG.md) for previous changes.
