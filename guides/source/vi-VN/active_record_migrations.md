Active Record Migrations
========================

Migrations là một tính năng của Active Record nó cho phép bạn phát triển lược đồ(schema) cơ sở dữ liệu của bạn qua thời gian. 
Thay vì viết các hiệu chỉnh lược đồ trong SQL thuần,
migrations cho phép bạn dùng Ruby DSL để mô tả thay đổi của các bảng trong cơ sở dữ liệu của bạn.

Sau khi đọc bài hướng dẫn này, bạn sẽ biết:

* Các generators bạn có thể dùng để tạo chúng.
* Các methods Active Record cung cấp để thao tác cở sở dữ liệu.
* Các bin/rails tasks.
* Làm thế nào để migrations liên quan đến `schema.rb`.

--------------------------------------------------------------------------------

Tổng quan về Migration
------------------

Migrations là một phương pháp hiệu quả để
[sửa đổi lược đồ cơ sở dữ liệu của bạn qua thời gian](https://en.wikipedia.org/wiki/Schema_migration)
một cách nhất quán và dễ dàng. Chúng dùng Ruby DSL nên bạn không cần phải viết SQL bằng tay, 
cho phép lược đồ và thay đổi cơ sở dữ liệu một cách độc lập.

Bạn có thể nghĩ mỗi migration như là một phiên bản mới của cơ sở dữ liệu. Một
lược đồ(schema) bắt đầu với không có gì trong nó, và mỗi migration hiệu chỉnh nó để thêm, 
xóa các bảng, các cột, hoặc các thực thể. Active Record biết làm thế nào để cập nhật lược đồ của bạn 
theo thời gian, mang nó từ bất kỳ thời điểm nào đến phiên bản mới nhất. Active Record ngoài ra còn cập nhật file
`db/schema.rb` để trùng với cơ sở dữ liệu mới nhất của bạn.

Ở đây là một ví dụ về migration:

```ruby
class CreateProducts < ActiveRecord::Migration[5.0]
  def change
    create_table :products do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
```

Đây là migration thêm một bảng được gọi là `products` với một string column được gọi là
`name` và một text column được gọi là `description`. Một khóa chính(primary key) column được gọi là `id`
sẽ được thêm một cách ngầm định, nó là khóa chính mặc định dành cho tất cả các Active
Record models.  Trong khi đó, `timestamps` macro thêm 2 columns, `created_at` và
`updated_at`. Đây là những columns đặc biệt được quản lý tự động bởi Active Record
nếu chúng tồn tại.

Lưu ý rằng chúng ta định nghĩa thay đổi những gì chúng ta muốn theo thời gian hướng về phía trước.
Trước khi migration này chạy, ở đây ta sẽ không có bảng nào cả. Sau đó, các bảng sẽ tồn tại. 
Active Record ngoài ra còn biết làm thế nào để nghịch đảo quá trình migration này: nếu chúng ta rollback quá trình migration, 
nó sẽ xóa bảng.

Trên những cơ sở dữ liệu hổ trợ transactions với những câu lệnh thay đổi lược đồ,
migrations được bao phủ trong transaction. Nếu cơ sở dữ liệu không hỗ trợ điều này thì
khi một migration thất bại thì những phần mà nó tạo thành công sẽ không bị rollback. 
Bạn sẽ phải rollback những thay đổi này bằng tay.

Lưu ý: Có những truy vấn nhất định không thể chạy trong transaction. Nếu adapter của bạn hỗ trợ DDL transactions 
bạn có thể dùng `disable_ddl_transaction!` để
tắt chúng dành cho một single migration.

Nếu bạn muốn migration làm một việc gì đó mà Active Record không biết làm thế nào để nghịch đảo, bạn có thể dùng `reversible`:

```ruby
class ChangeProductsPrice < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      change_table :products do |t|
        dir.up   { t.change :price, :string }
        dir.down { t.change :price, :integer }
      end
    end
  end
end
```

Như là một sự lựa chọn, bạn có thể sử dụng `up` và `down` thay vì `change`:

```ruby
class ChangeProductsPrice < ActiveRecord::Migration[5.0]
  def up
    change_table :products do |t|
      t.change :price, :string
    end
  end

  def down
    change_table :products do |t|
      t.change :price, :integer
    end
  end
end
```

Tạo một Migration
--------------------

### Tạo một Migration độc lập

Các Migrations được chứa trong các tập tin nằm trong `db/migrate`, một cho mỗi
migration class. Tên của file có dạng như sau:
`YYYYMMDDHHMMSS_create_products.rb`, đó là một UTC timestamp(dấu thời gian)
migration theo sau bởi dấu gạch dưới và theo sau là tên của migration. 
Tên của migration class (dưới dạng CamelCased)
nên giống như phần sau của tên file như ở trên. ví dụ
`20080906120000_create_products.rb` nên định nghĩa class `CreateProducts` và
`20080906120001_add_details_to_products.rb` nên định nghĩa
`AddDetailsToProducts`. Rails dùng timestamp này để xác định migration nào
nên chạy trước theo thứ tự, nên nếu bạn đang sao chép một migration từ một ứng dụng khác 
hoặc tạo ra một file bởi chính bạn, hãy chú ý vị trí của nó theo thứ tự.

Dĩ nhiên, tính toán timestamps là không dễ chút nào, nên Active Record cung cấp một
generator để xử lý nó giúp bạn:

```bash
$ bin/rails generate migration AddPartNumberToProducts
```

Lệnh trên sẽ tạo ra một migration rỗng với một tên class thích hợp như sau:

```ruby
class AddPartNumberToProducts < ActiveRecord::Migration[5.0]
  def change
  end
end
```

Nếu tên migration theo dạng "AddXXXToYYY" hoặc "RemoveXXXFromYYY" và theo sau bởi danh sách tên 
column và kiểu của column đó thì một migration chứa câu lệnh `add_column` và `remove_column` sẽ được tạo.

```bash
$ bin/rails generate migration AddPartNumberToProducts part_number:string
```

sẽ tạo

```ruby
class AddPartNumberToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :part_number, :string
  end
end
```

Nếu bạn muốn thêm một index trên một column mới, bạn có thể làm như sau:

```bash
$ bin/rails generate migration AddPartNumberToProducts part_number:string:index
```

sẽ tạo

```ruby
class AddPartNumberToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :part_number, :string
    add_index :products, :part_number
  end
end
```


Tương tự, bạn có thể tạo một migration để xóa một column từ dòng lệnh(command line):

```bash
$ bin/rails generate migration RemovePartNumberFromProducts part_number:string
```

tạo ra

```ruby
class RemovePartNumberFromProducts < ActiveRecord::Migration[5.0]
  def change
    remove_column :products, :part_number, :string
  end
end
```

Có thể tạo nhiều column như sau:

```bash
$ bin/rails generate migration AddDetailsToProducts part_number:string price:decimal
```

tạo ra

```ruby
class AddDetailsToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :part_number, :string
    add_column :products, :price, :decimal
  end
end
```

Nếu tên migration có dạng "CreateXXX" và
theo sau bởi danh sách các tên column và kiểu của column thì một migration sẽ tạo bảng có tên
XXX với các columns theo sau sẽ cũng được tạo. Ví dụ:

```bash
$ bin/rails generate migration CreateProducts name:string part_number:string
```

tạo ra

```ruby
class CreateProducts < ActiveRecord::Migration[5.0]
  def change
    create_table :products do |t|
      t.string :name
      t.string :part_number
    end
  end
end
```

Như thường lệ, những gì được tạo ra cho bạn chỉ là điểm khởi đầu. Bạn có thể hoặc
xóa nó bằng cách sửa đổi
`db/migrate/YYYYMMDDHHMMSS_add_details_to_products.rb` file.

Ngoài ra, generator chấp nhận kiểu column là `references` (ngoài ra có thể là kiểu
`belongs_to`). Ví dụ:

```bash
$ bin/rails generate migration AddUserRefToProducts user:references
```

tạo ra

```ruby
class AddUserRefToProducts < ActiveRecord::Migration[5.0]
  def change
    add_reference :products, :user, foreign_key: true
  end
end
```

Migration này sẽ tạo một `user_id` column và một index tương ứng.
Thêm về các options của `add_reference`, truy cập [API documentation](http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_reference).

Ngoài ra còn có một generator sẽ tạo join tables nếu `JoinTable` là một phần của tên:

```bash
$ bin/rails g migration CreateJoinTableCustomerProduct customer product
```

sẽ sinh ra migration như sau:

```ruby
class CreateJoinTableCustomerProduct < ActiveRecord::Migration[5.0]
  def change
    create_join_table :customers, :products do |t|
      # t.index [:customer_id, :product_id]
      # t.index [:product_id, :customer_id]
    end
  end
end
```

### Model Generators

Model và scaffold generators sẽ tạo các migrations tương ứng với việc tạo một
model mới. Migration sẽ sẵng sàng chứa các chỉ dẫn dành cho việc tạo các bảng liên quan. 
Nếu bạn báo cho Rails những columns bạn muốn, thì những câu lệnh dành cho việc
thêm những columns sẽ ngoài ra được tạo. Ví dụ, chạy:

```bash
$ bin/rails generate model Product name:string description:text
```

sẽ tạo ra một migration giống như thế này

```ruby
class CreateProducts < ActiveRecord::Migration[5.0]
  def change
    create_table :products do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
```

Bạn có thể thêm nhiều tên column và kiểu của column nếu bạn muốn.

### Passing Modifiers

Một vài trường hợp sử dụng phổ biến [type modifiers](#column-modifiers) có thể được đặt trực tiếp trên command line. 
Chúng được bao bởi dấu ngoặc móc và theo sau là kiểu trường(field):

Ví dụ, ta chạy lệnh:

```bash
$ bin/rails generate migration AddDetailsToProducts 'price:decimal{5,2}' supplier:references{polymorphic}
```

sẽ sinh ra một migration giống như thế này

```ruby
class AddDetailsToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :price, :decimal, precision: 5, scale: 2
    add_reference :products, :supplier, polymorphic: true
  end
end
```

Mẹo: Xem thêm để biết các generators khác.

Viết một Migration
-------------------

Một khi bạn đã tạo ra migration của bạn bằng cách sử dụng một trong những generators đã đến lúc
bắt đầu làm!

### Tạo một bảng(Table)

Method `create_table` là một trong những phương thức căn bản nhất, nhưng hầu hết thời gian,
sẽ được tạo ra bằng cách dùng một model hoặc dùng generator scaffold. Một cách sử dụng điển hình là:

```ruby
create_table :products do |t|
  t.string :name
end
```

Nó tạo ra một bảng `products` với một column có tên là `name` (và như thảo luận ở bên dưới, 
ngoài ra sẽ tạo một column ngầm định là `id`).

Bởi mặc định, `create_table` sẽ tạo ra một khóa chính(primary key) được gọi là `id`. Bạn có thể thay đổi tên của 
khóa chính với option `:primary_key` (đừng quên cập nhật model tương ứng) hoặc, nếu bạn không muốn một khóa chính, bạn 
có thể pass option `id: false`. Nếu bạn cần đặt một option cơ sở dữ liệu cụ thế
bạn có thể đặt một mẫu SQL trong option `:options`. Ví dụ:

```ruby
create_table :products, options: "ENGINE=BLACKHOLE" do |t|
  t.string :name, null: false
end
```

nó sẽ nối `ENGINE=BLACKHOLE` vào câu lệnh SQL được sử dụng để tạo bảng.

Ngoài ra bạn có thể đặt option `:comment` với bất kỳ mô tả dành cho bảng
mà nó sẽ được chứa trong cơ sở dữ liệu và có thể được xem bởi các công cụ quản trị cơ sở dữ liệu(database administration)
, chẳng hạn như MySQL Workbench hoặc PgAdmin III. Nó rất đáng để đặt các
comments trong các migrations dành cho ứng dụng với các cơ sở dữ liệu lớn vì nó giúp mọi người hiểu được
mô hình dữ liệu (data model) và tạo tài liệu.
Hiện tại chỉ có MySQL và PostgreSQL hỗ trợ comments.

### Creating a Join Table

Migration method `create_join_table` tạo một HABTM (has and belongs to
many) join table. Một kiểu sử dụng điển hình là:

```ruby
create_join_table :products, :categories
```

nó tạo ra một bảng `categories_products` với 2 columns được gọi là
`category_id` và `product_id`. Những columns có option `:null` sẽ thành
`false` bởi mặc định. Điều này có thể được ghi đè với chỉ thị option `:column_options`, như sau:

```ruby
create_join_table :products, :categories, column_options: { null: true }
```

Bởi mặc định, tên của join table đến từ sự hợp nhất của 2 đối số được cung cấp cho method create_join_table, 
theo thứ tự alphabet.
Để tùy chỉnh tên của bảng, cung cấp một option `:table_name`:

```ruby
create_join_table :products, :categories, table_name: :categorization
```

tạo một bảng `categorization`.

`create_join_table` ngoài ra còn chấp nhận block, nó cho phép bạn có thể thêm các index
(nó sẽ không được tạo bởi mặc định) hoặc thêm column:

```ruby
create_join_table :products, :categories do |t|
  t.index :product_id
  t.index :category_id
end
```

### Thay đổi bảng Tables

Một method anh em của `create_table` là `change_table`, được dùng để thay đổi các bảng đã tồn tại. 
Nó được dùng giống như `create_table` nhưng object
với nhiều thủ thuật với block hơn. Ví dụ:

```ruby
change_table :products do |t|
  t.remove :description, :name
  t.string :part_number
  t.index :part_number
  t.rename :upccode, :upc_code
end
```

xóa các columns `description` và `name`, tạo một một string column `part_number`
và thêm index trên column đó. Cuối cùng đổi tên column `upccode` thành `upc_code`.

### Thay đổi Columns

Giống như `remove_column` và `add_column` Rails cung cấp method `change_column`
migration.

```ruby
change_column :products, :part_number, :text
```

Điều này thay đổi column `part_number` trên bảng products thành field `:text`.
lưu ý rằng `change_column` là lệnh không thể nghịch đảo.

Bên cạnh `change_column`, các methods `change_column_null` và `change_column_default`
được sử dụng để thay đổi một ràng buộc(constraint) not null và giá trị mặc định của một column.

```ruby
change_column_null :products, :name, false
change_column_default :products, :approved, from: true, to: false
```

Đây là tập field `:name` trên products với column `NOT NULL` và giá trị mặc định của
field `:approved` từ true thành false.

Lưu ý: Bạn ngoài ra có thể viết `change_column_default` migration như sau:
`change_column_default :products, :approved, false`, nhưng không giống như ví dụ trước, 
điều này sẽ làm cho migration của bạn không thể đảo ngược được.

### Column Modifiers

Column modifiers có thể được apply khi tạo hoặc thay đổi một column:

* `limit`        Thiết lập kích cỡ tối đa của fields `string/text/binary/integer`.
* `precision`    Định nghĩa độ chính xác dành cho fields `decimal`, trình bày
tổng số chữ số trong số.
* `scale`        Định nghĩa sự mở rộng(scale) cho fields `decimal` fields, trình bày
số chữ số sau phần thập phân.
* `polymorphic`  Thêm một column `type` dành cho sự phối hợp(associations) `belongs_to`.
* `null`         Cho phép hoặc không cho phép giá trị `NULL` trong column.
* `default`      Cho phép thiết lập giá trị mặc định trên column. Lưu ý rằng nếu bạn dùng một giá trị động(dynamic) 
(chẳng hạn như date), mặc định sẽ chỉ được tính
lần đầu tiên (ví dụ dựa trên ngày migration được áp dụng).
* `index`        Thêm một index dành cho column.
* `comment`      Thêm comment dành cho column.

Một vài adapters có thể hỗ trợ thêm các options; xem thêm các adapter cụ thể trong API docs
để biết thêm.

Lưu ý: `null` và `default` không thể chỉ định thông qua command line.

### Khóa ngoại (Foreign Keys)

Mặc dù không bắt buộc, bạn có thể muốn thêm ràng buộc khóa ngoại(foreign key) với
[guarantee referential integrity](#active-record-and-referential-integrity).

```ruby
add_foreign_key :articles, :authors
```

Lệnh trên sẽ thêm khóa ngoại cho column `author_id` của bảng `articles`
. Khóa ngoại sẽ tham chiếu đến column `id` của bảng `authors`. Nếu
tên column không bắt nguồn từ tên table, bạn có thể dùng
`:column` và `:primary_key` như là options.

Rails sẽ tạo một tên dành cho mỗi foreign key bắt đầu với
`fk_rails_` theo sau là 10 ký tự được tạo theo mẫu
từ `from_table` và `column`.
Có một option `:name` để chỉ rõ tên khác nhau nếu cần.

Lưu ý: Active Record chỉ hỗ trợ single column foreign keys. `execute` và
`structure.sql` được yêu cầu dùng các khóa ngoại phức hợp(foreign keys composite). Xem
[Schema Dumping và bạn](#schema-dumping-and-you).

Xóa một khóa ngoại tương đối dễ dàng như sau:

```ruby
# let Active Record figure out the column name
remove_foreign_key :accounts, :branches

# remove foreign key for a specific column
remove_foreign_key :accounts, column: :owner_id

# remove foreign key by name
remove_foreign_key :accounts, name: :special_fk_name
```

### Khi Helpers là không đủ

Nếu các helpers được cung cấp bởi Active Record bạn có thể dùng method `execute`
method để thực thi SQL tùy ý:

```ruby
Product.connection.execute("UPDATE products SET price = 'free' WHERE 1=1")
```

Để biết thêm chi tiết về các methods riêng lẻ, kiểm tra tài liệu API.
Đặc biệt là tài liệu cho
[`ActiveRecord::ConnectionAdapters::SchemaStatements`](http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html)
(nó cung cấp các method thích hợp trong `change`, `up` và `down`),
[`ActiveRecord::ConnectionAdapters::TableDefinition`](http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/TableDefinition.html)
(nó cung cấp các phương thức thích hợp trên object được gọi bởi `create_table`)
và
[`ActiveRecord::ConnectionAdapters::Table`](http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/Table.html)
(nó cung cấp các phương thức thích hợp trên object được gọi bởi `change_table`).

### Dùng method `change`

Method `change` là một phương thức chính để viết migrations. Nó làm việc với các trường hợp chính, 
nơi Active Record biết làm thế nào để đảo ngược migration một cách tự động. Hiện tại, method `change` 
chỉ hỗ trợ những migration sau:

* add_column
* add_foreign_key
* add_index
* add_reference
* add_timestamps
* change_column_default (phải cung cấp một :from và :to)
* change_column_null
* create_join_table
* create_table
* disable_extension
* drop_join_table
* drop_table (phải cung cấp một block)
* enable_extension
* remove_column (phải cung cấp một type)
* remove_foreign_key (phải cung cấp một bảng thứ hai)
* remove_index
* remove_reference
* remove_timestamps
* rename_column
* rename_index
* rename_table

`change_table` ngoài ra có thể đảo ngược, miễn là block không gọi `change`,
`change_default` hoặc `remove`.

`remove_column` có thể đảo ngược nếu bạn cung cấp kiểu của column như là đối số thứ 3. 
cung cấp các column gốc, ngược lại Rails không thế
tạo lại column khi rolling back:

```ruby
remove_column :posts, :slug, :string, null: false, default: '', index: true
```

Nếu bạn định sử dụng bất kỳ method khác, bạn nên dùng `reversible`
hoặc viết `up` và `down` thay vì dùng `change`.

### Sử dụng method `reversible`

Các migrations phức tạp có thể yêu cầu các xử lý mà Active Record không biết làm thế nào để
đảo ngược. Bạn có thể dùng `reversible` để chỉ định những gì cần làm khi chạy một
migration và những gì khác phải làm khi đang đảo ngược nó. Ví dụ:

```ruby
class ExampleMigration < ActiveRecord::Migration[5.0]
  def change
    create_table :distributors do |t|
      t.string :zipcode
    end

    reversible do |dir|
      dir.up do
        # add a CHECK constraint
        execute <<-SQL
          ALTER TABLE distributors
            ADD CONSTRAINT zipchk
              CHECK (char_length(zipcode) = 5) NO INHERIT;
        SQL
      end
      dir.down do
        execute <<-SQL
          ALTER TABLE distributors
            DROP CONSTRAINT zipchk
        SQL
      end
    end

    add_column :users, :home_page_url, :string
    rename_column :users, :email, :email_address
  end
end
```

Dùng `reversible` sẽ chắc chắn rằng các chỉ dẫn được thực thi theo
đúng thứ tự. Nếu ví dụ của migration trước là đã đảo ngược,
thì block `down` sẽ chạy sau column `home_page_url` là được xóa và
trước khi bảng `distributors` bị bỏ.

Đôi khi migration sẽ làm một điều gì đó mà không thể đảo ngược hoàn toàn; ví dụ
, nó có thể hủy một vài dữ liệu. Trong trường hợp này, bạn có thể đưa ra(raise)
`ActiveRecord::IrreversibleMigration` trong block `down` của bạn. Nếu một ai đó thử
đảo ngược migration của bạn, một message lỗi sẽ thông báo diều đó là không được phép.

### Sử dụng methods `up`/`down`

Ngoài ra bạn có thể dùng method migration sử dụng `up` và `down` thay thì method `change`.
Method `up` nên mô tả sự biến đổi mà bạn muốn thực hiện với
lược đồ(schema), và method `down` của migration của bạn nên đảo ngược các biến đổi
được hoàn thành bởi phương thức `up`. Nói cách khác, lược đồ cơ sở dữ liệu nên không thay đổi
nếu bạn sử dụng `up` theo sau là `down`. Ví dụ, nếu bạn
tạo một bảng trong method `up`, bạn nên bỏ nó trong method `down`. Nó là
để thực hiện biến đổi theo thứ tự ngược mà nó đã làm với method up
. Ví dụ trong phần `reversible` là tương đương với:

```ruby
class ExampleMigration < ActiveRecord::Migration[5.0]
  def up
    create_table :distributors do |t|
      t.string :zipcode
    end

    # add a CHECK constraint
    execute <<-SQL
      ALTER TABLE distributors
        ADD CONSTRAINT zipchk
        CHECK (char_length(zipcode) = 5);
    SQL

    add_column :users, :home_page_url, :string
    rename_column :users, :email, :email_address
  end

  def down
    rename_column :users, :email_address, :email
    remove_column :users, :home_page_url

    execute <<-SQL
      ALTER TABLE distributors
        DROP CONSTRAINT zipchk
    SQL

    drop_table :distributors
  end
end
```

Nếu migratio không thể nghịch đảo, bạn nên raise
`ActiveRecord::IrreversibleMigration` từ method `down`. If someone tries
to revert your migration, một message lỗi sẽ thông báo diều đó là không được phép.

### Đảo ngược các Migrations trước

Bạn có thể dùng tính năng của Active Record's để rollback migrations dùng method `revert`:

```ruby
require_relative '20121212123456_example_migration'

class FixupExampleMigration < ActiveRecord::Migration[5.0]
  def change
    revert ExampleMigration

    create_table(:apples) do |t|
      t.string :variety
    end
  end
end
```

Method `revert` ngoài ra chấp nhận một block các chỉ thị để đảo ngược.
Ví dụ, tưởng tượng rằng `ExampleMigration` là committed và nó
sau đó quyết định tốt nhất nếu dùng Active Record validations,
trong chỗ ràng buộc `CHECK`, để xác thực zipcode.

```ruby
class DontUseConstraintForZipcodeValidationMigration < ActiveRecord::Migration[5.0]
  def change
    revert do
      # copy-pasted code from ExampleMigration
      reversible do |dir|
        dir.up do
          # add a CHECK constraint
          execute <<-SQL
            ALTER TABLE distributors
              ADD CONSTRAINT zipchk
                CHECK (char_length(zipcode) = 5);
          SQL
        end
        dir.down do
          execute <<-SQL
            ALTER TABLE distributors
              DROP CONSTRAINT zipchk
          SQL
        end
      end

      # The rest of the migration was ok
    end
  end
end
```

Migration giống như thế có thể được viết mà không dùng `revert`
nhưng điều này có liên quan đến một vài bược nữa: đảo ngược thứ tự của 
`create_table` và `reversible`, thay thế `create_table`
bằng `drop_table`, và cuối cùng thay thế `up` bằng `down` và ngược lại.
Tất cả được chăm nom bởi `revert`.

Lưu ý: Nếu bạn muốn thêm một kiểm tra ràng buộc giống như trong ví dụ trên,
bạn sẽ phải dùng `structure.sql` như là một dump method. Xem
[Schema Dumping và bạn](#schema-dumping-and-you).

Chạy Migrations
------------------

Rails cung cấp một tập hợp bin/rails tasks để chạy các migrations.

Migration đầu tiên liên quan đến bin/rails task mà bạn sẽ dùng chắc chắn là
`rails db:migrate`. Trong hình thức cơ bản nhất nó chỉ chạy `change` hoặc `up`
cho tất cả các migrations chưa được chạy. Nếu
không có migration nào, nó sẽ thoát. Nó ngoài ra chạy các migration theo thứ tự thời gian tạo các migration.

Lưu ý rằng chạy task `db:migrate` ngoài ra còn gọi task `db:schema:dump`, nó
sẽ cập nhật `db/schema.rb` cảu bạn để trùng với cấu trúc cơ sở dữ liệu của bạn.

Nếu bạn chỉ định một phiên bản đích, Active Record sẽ chạy các migrations được yêu cầu
(change, up, down) cho đến khi nó đạt đến phiên bản đích. Phiên bản(version)
là số tiền tố trước tên file migration. Ví dụ, để migrate
đến phiên bản 20080906120000 ta chạy:

```bash
$ bin/rails db:migrate VERSION=20080906120000
```

Nếu phiên bản 20080906120000 lớn hơn phiên bản hiện tại (ví dụ, nó là một
migrating tiến lên), điều này sẽ chạy `change` (hoặc `up`) trên tất cả các migrations cho đến
phiên bản 20080906120000, và sẽ không thực thi bất kì migrations nào sau đó. Nếu
migrating là lùi, thì nó sẽ tạo method `down` trên tất cả các migrations
lùi, nhưng không bao gồm phiên bản 20080906120000.

### Rolling Back

Một task phổ biến là rollback migration sau cùng. Ví dụ, nếu bạn có sai sót nào đó ở phiên bản mới nhất. 
Thay vì phải theo dõi các phiên bản
và các số đi với các phiên bản trước thì bạn có thể chạy:

```bash
$ bin/rails db:rollback
```

Lệnh trên sẽ rollback phiên bản migration mới nhất, bằng cách đảo ngược method `change`
hoặc bằng cách chạy method `down`. Nếu bạn cần hoàn tác một vài
migrations bạn có thể thêm tham số `STEP`:

```bash
$ bin/rails db:rollback STEP=3
```

sẽ đảo ngược 3 migrations sau cùng.

Task `db:migrate:redo` là một lệnh tắt để rollback và migration backup lại. 
Giống như với task `db:rollback`, bạn có thể dùng tham số `STEP`
như sau:

```bash
$ bin/rails db:migrate:redo STEP=3
```

Cả hai lệnh bin/rails đều làm bất cứ thứ gì bạn không thế làm với `db:migrate`. Chúng
hiệu quả hơn, vì bạn không cần phải chỉ rõ phiên bản để migrate đến.

### Thiết lập cơ sở dữ liệu(Database)

Task `rails db:setup` sẽ tạo cơ sở dữ liệu, load lược đồ csdl và thực hiện
seed dữ liệu vào csdl.

### Resetting the Database

Task `rails db:reset` sẽ xóa csdl và thiết lập lại nó. Chức năng này
tương đương `rails db:drop db:setup`.

Lưu ý: Điều này không giống như tất cả các migration. Nó sẽ chỉ dùng
nội dung của `db/schema.rb` hiện tại hoặc file `db/structure.sql`. Nếu migration không thể rolled back,
`rails db:reset` không thể giúp bạn. Để tìm hiểu thêm, xem phần
[Schema Dumping và bạn](#schema-dumping-and-you).

### Chạy các Migrations chỉ định

Nếu bạn cần chạy các migration chỉ định như `up` và `down`, lệnh `db:migrate:up` và
`db:migrate:down` sẽ làm điều đó. Chỉ định phiên bản thích hợp và
migration tương ứng sẽ có các method `change`, `up` hoặc `down`
được gọi, ví dụ:

```bash
$ bin/rails db:migrate:up VERSION=20080906120000
```

sẽ chạy phiên bản migration 20080906120000 bởi việc chạy method `change` (hoặc method
`up`). This task will
first check whether the migration is already performed and will do nothing if
Active Record believes that it has already been run.

### Chạy các Migrations trong các môi trường khác

Bởi mặc định `bin/rails db:migrate` sẽ chạy trong môi trường `development`.
Để chạy các migrations với các môi trường khác bạn có thể chỉ rõ nó bằng cách dùng
biến môi trường `RAILS_ENV` trong khi chạy lệnh trên. Ví dụ chạy các
migrations với môi trường `test` như sau:

```bash
$ bin/rails db:migrate RAILS_ENV=test
```

### Changing the Output of Running Migrations

By default migrations tell you exactly what they're doing and how long it took.
A migration creating a table and adding an index might produce output like this

```bash
==  CreateProducts: migrating =================================================
-- create_table(:products)
   -> 0.0028s
==  CreateProducts: migrated (0.0028s) ========================================
```

Several methods are provided in migrations that allow you to control all this:

| Method               | Purpose
| -------------------- | -------
| suppress_messages    | Takes a block as an argument and suppresses any output generated by the block.
| say                  | Takes a message argument and outputs it as is. A second boolean argument can be passed to specify whether to indent or not.
| say_with_time        | Outputs text along with how long it took to run its block. If the block returns an integer it assumes it is the number of rows affected.

For example, this migration:

```ruby
class CreateProducts < ActiveRecord::Migration[5.0]
  def change
    suppress_messages do
      create_table :products do |t|
        t.string :name
        t.text :description
        t.timestamps
      end
    end

    say "Created a table"

    suppress_messages {add_index :products, :name}
    say "and an index!", true

    say_with_time 'Waiting for a while' do
      sleep 10
      250
    end
  end
end
```

tạo ra

```bash
==  CreateProducts: migrating =================================================
-- Created a table
   -> and an index!
-- Waiting for a while
   -> 10.0013s
   -> 250 rows
==  CreateProducts: migrated (10.0054s) =======================================
```

Nếu bạn muốn Active Record không xuất ra bất cứ thứ gì, thì chạy `rails db:migrate
VERBOSE=false` sẽ không có xuất lệnh.

Thay đổi Migrations hiện tại
----------------------------

Đôi khi bạn sẽ mắc phải sai lầm khi viết một migration. Nếu bạn
đã chạy migration đó, thì bạn không thể hiệu chỉnh migration và chạy
migration lại: Rails nghĩ nó đã chạy migration và sẽ không
làm gì khi bạn chạy `rails db:migrate`. Bạn phải rollback migration (ví dụ với: `bin/rails db:rollback`), 
chỉnh sửa migration của bạn và chạy `rails db:migrate` để chỉnh sửa phiên bản đó.

Nói chung, chỉnh sửa một migrations không phải là một ý hay. Bạn sẽ tạo thêm công việc
cho bản thân và đồng nghiệp của bạn và có thể dẫn đến các vấn đề nhức đầu
nếu tồn tại một phiên bản của migration đã chạy trên môi trường production. 
Thay vào đó, thay vào đó bạn nên viết các migration mới thực hiện những thay đổi
mà bạn yêu cầu. Editing a freshly generated migration that has not yet been
committed to source control (or, more generally, which has not been propagated
beyond your development machine) is relatively harmless.

The `revert` method can be helpful when writing a new migration to undo
previous migrations in whole or in part
(see [Reverting Previous Migrations](#reverting-previous-migrations) above).

Schema Dumping and You
----------------------

### What are Schema Files for?

Migrations, mighty as they may be, are not the authoritative source for your
database schema. That role falls to either `db/schema.rb` or an SQL file which
Active Record generates by examining the database. They are not designed to be
edited, they just represent the current state of the database.

There is no need (and it is error prone) to deploy a new instance of an app by
replaying the entire migration history. It is much simpler and faster to just
load into the database a description of the current schema.

For example, this is how the test database is created: the current development
database is dumped (either to `db/schema.rb` or `db/structure.sql`) and then
loaded into the test database.

Schema files are also useful if you want a quick look at what attributes an
Active Record object has. This information is not in the model's code and is
frequently spread across several migrations, but the information is nicely
summed up in the schema file. The
[annotate_models](https://github.com/ctran/annotate_models) gem automatically
adds and updates comments at the top of each model summarizing the schema if
you desire that functionality.

### Types of Schema Dumps

There are two ways to dump the schema. This is set in `config/application.rb`
by the `config.active_record.schema_format` setting, which may be either `:sql`
or `:ruby`.

If `:ruby` is selected, then the schema is stored in `db/schema.rb`. If you look
at this file you'll find that it looks an awful lot like one very big
migration:

```ruby
ActiveRecord::Schema.define(version: 20080906171750) do
  create_table "authors", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "products", force: true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "part_number"
  end
end
```

In many ways this is exactly what it is. This file is created by inspecting the
database and expressing its structure using `create_table`, `add_index`, and so
on. Because this is database-independent, it could be loaded into any database
that Active Record supports. This could be very useful if you were to
distribute an application that is able to run against multiple databases.

NOTE: `db/schema.rb` cannot express database specific items such as triggers,
sequences, stored procedures or check constraints, etc. Please note that while
custom SQL statements can be run in migrations, these statements cannot be reconstituted
by the schema dumper. If you are using features like this, then you
should set the schema format to `:sql`.

Instead of using Active Record's schema dumper, the database's structure will
be dumped using a tool specific to the database (via the `db:structure:dump`
rails task) into `db/structure.sql`. For example, for PostgreSQL, the `pg_dump`
utility is used. For MySQL and MariaDB, this file will contain the output of
`SHOW CREATE TABLE` for the various tables.

Loading these schemas is simply a question of executing the SQL statements they
contain. By definition, this will create a perfect copy of the database's
structure. Using the `:sql` schema format will, however, prevent loading the
schema into a RDBMS other than the one used to create it.

### Schema Dumps and Source Control

Because schema dumps are the authoritative source for your database schema, it
is strongly recommended that you check them into source control.

`db/schema.rb` contains the current version number of the database. This
ensures conflicts are going to happen in the case of a merge where both
branches touched the schema. When that happens, solve conflicts manually,
keeping the highest version number of the two.

Active Record và tính toàn vẹn dữ liệu
---------------------------------------

The Active Record way claims that intelligence belongs in your models, not in
the database. As such, features such as triggers or constraints,
which push some of that intelligence back into the database, are not heavily
used.

Validations such as `validates :foreign_key, uniqueness: true` are one way in
which models can enforce data integrity. The `:dependent` option on
associations allows models to automatically destroy child objects when the
parent is destroyed. Like anything which operates at the application level,
these cannot guarantee referential integrity and so some people augment them
with [foreign key constraints](#foreign-keys) in the database.

Although Active Record does not provide all the tools for working directly with
such features, the `execute` method can be used to execute arbitrary SQL.

Migrations and Seed Data
------------------------

Mục đích chính của tính năng migration trong Rails là để đưa ra những lệnh hiệu chỉnh
lược đồ dùng một quy trình nhất quán. Migrations ngoài ra có thể được dùng để thêm hoặc chỉnh sửa dữ liệu. 
Điều này hữu ích nếu một cơ sở dữ liệu đã tồn tại mà không thể xóa hoặc
tạo lại, chẳng hạn cơ sở dữ liệu production.

```ruby
class AddInitialProducts < ActiveRecord::Migration[5.0]
  def up
    5.times do |i|
      Product.create(name: "Product ##{i}", description: "A product.")
    end
  end

  def down
    Product.delete_all
  end
end
```

Để thêm các dữ liệu ban đầu sau khi tạo một cơ sở dữ liệu, Rails có một tính năng xây dựng sẵng
gọi là 'seeds' nó giúp việc tạo dữ liệu nhanh và dễ dàng hơn. Điều này đặc biệt hữu ích
khi tải lại cơ sở dữ liệu thường xuyên trong môi trường development và test.
Rất dễ để bắt đầu với tính năng này: chỉ cần viết mã vào `db/seeds.rb` và chạy `rails db:seed`:

```ruby
5.times do |i|
  Product.create(name: "Product ##{i}", description: "A product.")
end
```

Phương pháp này giúp cho việc tạo dữ liệu dành cho một ứng dụng ban đầu dễ dàng hơn.
