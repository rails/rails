 
*   If `first_or_create` is invoked like this
    `physician.patients.first_or_create` then association record
    is created.

    However `physician.patients.where(name: 'neeraj').first_or_create`
    does not create the association record.

    In the first case `first_or_create` is being invoked on
    `CollectionProxy` instance. However in the second instance
    `physician.patients.where(name: 'neeraj')` returns a `Relation`
    object and not a `CollectionProxy` object.

    Fix is to check if the relation object happens to have
    `proxy_association` then invoke `create` on that
    `proxy_association`.

    Fixes #10144.

    *Neeraj Singh*
