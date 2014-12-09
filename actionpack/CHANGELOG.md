*   Ensure `append_info_to_payload` is called even if an exception is raised.

    Fixes an issue where when an exception is raised in the request the additonal
    payload data is not available.

    See:
    * https://github.com/rails/rails/pull/14903
    * https://github.com/roidrage/lograge/issues/37

    *Dieter Komendera*, *Margus Pärt*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/actionpack/CHANGELOG.md) for previous changes.
