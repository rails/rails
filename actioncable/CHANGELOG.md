*   Add `id` option to redis adapter so now you can distinguish
    ActionCable's redis connections among others. Also, you can set
    custom id in options.

    Before:
    ```
    $ redis-cli client list
    id=669 addr=127.0.0.1:46442 fd=8 name= age=18 ...
    ```

    After:
    ```
    $ redis-cli client list
    id=673 addr=127.0.0.1:46516 fd=8 name=ActionCable-PID-19413 age=2 ...
    ```

    *Ilia Kasianenko*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actioncable/CHANGELOG.md) for previous changes.
