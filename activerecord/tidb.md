## setup test databases

```
tidb=1 MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_PORT=4000 rake db:mysql:build
```

## run test

```
tidb=1 MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_PORT=4000 rake test:mysql2
```