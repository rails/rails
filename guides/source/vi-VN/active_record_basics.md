Active Record Cơ Bản
====================

Bài hướng dẫn này giới thiệu về Active Record.

Sau khi đọc bài hướng dẫn này, bạn sẽ biết:

* Object Relational Mapping(ORM) và Active Record là gì và làm thế nào chúng được sử dụng trong
  Rails.
* Làm thế nào Active Record thích hợp với mô hình Model-View-Controller.
* Làm thế nào dùng Active Record models để thao tác dữ liệu chứa trong một cơ sở dữ liệu quan hệ.
* Quy tắc đặt tên lược đồ(schema) Active Record.
* Khái niệm về cơ sở dữ liệu migrations, validations và callbacks.

--------------------------------------------------------------------------------

Active Record là gì?
----------------------

Active Record là M(model) trong [MVC](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller) - 
nó là một lớp của hệ thống chịu trách nhiệm trình bày các business
data và logic. Active Record giúp tạo ra và sử dụng các business
objects có dữ liệu được yêu cầu lưu trữ liên tục vào cơ sở dữ liệu. Nó là một thi hành của
Active Record pattern mà bản thân nó chính là một mô tả của hệ thống
Object Relational Mapping(ORM).

### The Active Record Pattern

[Active Record đã được mô tả bởi Martin Fowler](http://www.martinfowler.com/eaaCatalog/activeRecord.html)
trong quyển sách của ông ấy: _Patterns of Enterprise Application Architecture_. Trong
Active Record, các objects chứa cả dữ liệu(data) và hành vi(behavior) mà nó thao tác trên dữ liệu đó. Active Record đảm bảo truy cập dữ liệu
logic như là một phần của object sẽ hướng dẫn người sử dụng về các
object và làm thế nào để ghi(write) và đọc(read) từ cơ sở dữ liệu.

### Object Relational Mapping

[Object Relational Mapping](https://en.wikipedia.org/wiki/Object-relational_mapping), thường được gọi là ORM, là
một công nghệ kết nối đến các objects của một ứng dụng vào các bảng trong
một hệ thống cơ sở dữ liệu quan hệ. Bằng việc dùng ORM, các thuộc tính và
các mối quan hệ của các objects trong một ứng dụng có thể dễ dàng được lưu và
nhận từ một cơ sở dữ liệu mà không cần viết lệnh SQL trực tiếp và với ít mã truy cập cơ sở dữ liệu nhìn về tổng thể.

### Active Record as an ORM Framework

Active Record cung cấp cho chúng ta các kỹ thuật, các khả năng quan trọng nhất là:

* Trình bày các models và dữ liệu của chúng.
* Trình bày sự kết hợp giữa các models.
* Trình bày cây kế thừa thông qua mối quan hệ giữa các models.
* Xác thực(validate) models trước khi chúng thao tác trên cơ sở dữ liệu.
* Thực hiện thao tác cơ sở dữ liệu theo kiểu hướng đối tượng(object-oriented).

Quy ước hơn cấu hình (Convention over Configuration) trong Active Record
----------------------------------------------

Khi viết một ứng dụng sử dụng ngôn ngữ hoặc frameworks khác, chúng ta có thể cần viết nhiều mã cấu hình(configuration).
Điều này đặc biệt đúng với ORM frameworks nói chung. 
Tuy nhiên, nếu bạn tuân theo quy ước được thừa nhận bởi Rails, 
bạn sẽ chỉ cần viết rất ít mã cấu hình(trong một vài trường hợp thì không cần viết gì)
khi tạo Active Record models. Ý tưởng ở đây là, nếu như bạn cấu hình ứng dụng của 
bạn trong hầu hết thời gian thì điều này nên là một phương pháp mặc định. 
Vì vậy, cấu hình rõ ràng chỉ cần thiết trong trường hợp
bạn không thể tuân theo quy ước chuẩn.

### Quy tắc đặt tên

Mặc định, Active Record dùng một vài quy tắc đặt tên để tìm ra làm thế nào để
ánh xạ(mapping) giữa models và các bảng(tables) trong cơ sở dữ liệu nên được tạo. Rails sẽ
tự động số nhiều tên class của bạn để tìm ra chính xác bảng trong cơ sở dữ liệu. Ví dụ, bạn có
một class `Book`, vậy thì bạn nên có một bảng trong cơ sở dữ liệu tên là **books**. 
Kỹ thuật số nhiều cho tên trong Rails rất mạnh mẽ, nó có thể số nhiều tên (cũng như số ít)
cả các từ bình thường và từ bất quy tắc(Tiếng anh). Khi dùng tên class được ghép bởi hai hoặc nhiều từ,
tên model class nên tuân theo quy ước của Ruby,
dùng quy tắc CamelCase, trong khi tên bảng phải chứa các từ được phân cách bởi dấu gạch dưới(_). Ví dụ:

* Database Table - Số nhiều với dấu gạch dưới phân tách các từ (ví dụ: `book_clubs`).
* Model Class - Số ít với các từ đầu tiên của mỗi từ phải viết hoa - quy tắc CamelCase (ví dụ:
`BookClub`).

| Model / Class    | Table / Schema |
| ---------------- | -------------- |
| `Article`        | `articles`     |
| `LineItem`       | `line_items`   |
| `Deer`           | `deers`        |
| `Mouse`          | `mice`         |
| `Person`         | `people`       |


### Quy ước Schema

Active Record áp dụng quy ước đặt tên cho các columns trong các bảng của cơ sở dữ liệu,
phụ thuộc vào mục đích của các columns.

* **Foreign keys** - Khóa ngoại, là những fields nên được đặt tên theo mẫu
  `tensoit_tenbang_id` (ví dụ: `item_id`, `order_id`). Đây là những
  fields mà Active Record sẽ tìm kiếm khi bạn tạo ra sự kết hợp(associations) giữa các models.
* **Primary keys** - Khóa chính, theo mặc định, Active Record sẽ dùng một cột integer có tên là
  `id` như là khóa chính của bảng. Khi dùng [Active Record
  Migrations](active_record_migrations.html) để tạo các bảng, thì cột này sẽ được tự động tạo.

Ngoài ra còn có một vài columns thêm các tính năng cho một đối tượng Active Record:

* `created_at` - Tự động lấy thời gian hiện tại khi record lần đầu tiên được tạo.
* `updated_at` - Tự động lấy thời gian hiện tại bất kể khi nào record được cập nhật.
* `lock_version` - Thêm [optimistic
  locking](http://api.rubyonrails.org/classes/ActiveRecord/Locking.html) cho
  một model.
* `type` - Chỉ định model sử dụng [Single Table
  Inheritance](http://api.rubyonrails.org/classes/ActiveRecord/Base.html#class-ActiveRecord::Base-label-Single+table+inheritance).
* `(association_name)_type` - Chứa type dành cho
  [polymorphic associations](association_basics.html#polymorphic-associations).
* `(table_name)_count` - Được dùng để cache số objects thuộc
  associations. Ví dụ, một column `comments_count` trong một class `Article` mà nó
  có nhiều đối tượng `Comment` sẽ cache số comments tồn tại
  dành cho mỗi article.

NOTE: Mặc dù các tên cột này là tùy chọn, chúng thực tế được dành riêng bởi Active Record. 
Tránh sử dụng các từ khóa dành riêng trừ khi bạn muốn thêm các tính năng. 
Ví dụ, `type` là một từ khóa dành riêng được sử dụng để thiết kế một bảng dùng Single Table Inheritance (STI). 
Nếu bạn không dùng STI, thử một từ khóa khác có nghĩa tương đương chẳng hạn như "context", 
điều này vẫn cho phép mô tả chính xác dữ liệu mà bạn đang tạo.

Tạo Active Record Models
-----------------------------

Rất dễ để tạo ra Active Record models. Tất cả những gì bạn cần phải làm là
kế thừ từ class `ApplicationRecord` :

```ruby
# Ví dụ:
class Product < ApplicationRecord
end
```

Ví dụ trên sẽ tạo ra một `Product` model, ánh xạ tới bảng `products` trong cơ sở dữ liệu. 
Bằng cách làm điều này bạn có thể ánh xạ đến từng columns của mỗi
row trong bảng đó với thuộc tính(attributes) của object của model. Giả sử
bảng `products`đã được tạo dùng câu lệnh SQL như thế này:

```sql
CREATE TABLE products (
   id int(11) NOT NULL auto_increment,
   name varchar(255),
   PRIMARY KEY  (id)
);
```

Theo như lược đồ của bảng trên, bạn có thể viết lại code trong ruby giống như sau:

```ruby
p = Product.new
p.name = "Some Book"
puts p.name # "Some Book"
```

Ghi đè(Overriding) quy ước đặt tên
---------------------------------

Nếu bạn cần áp dụng các phương thức đặt tên khác hoặc cần dùng ứng dụng
Rails của bạn với một cơ sở dữ liệu cũ? Không vấn đề gì, bạn có thể dễ đàng ghi đè các quy ước mặc định.

`ApplicationRecord` kế thừa từ `ActiveRecord::Base`, nó định nghĩa một
số methods hữu ích. Bạn có thể dùng method `ActiveRecord::Base.table_name=`
để chỉ định tên bảng nên được dùng:

```ruby
class Product < ApplicationRecord
  self.table_name = "my_products"
end
```

Nếu bạn làm điều này, bạn sẽ phải định nghĩa thủ công tên lớp class name và lưu trữ
fixtures (my_products.yml) dùng method `set_fixture_class` trong định nghĩa test:

```ruby
class ProductTest < ActiveSupport::TestCase
  set_fixture_class my_products: Product
  fixtures :my_products
  ...
end
```

Ngoài ra có thể ghi đè column được dùng như là khóa chính của bảng
dùng method `ActiveRecord::Base.primary_key=` :

```ruby
class Product < ApplicationRecord
  self.primary_key = "product_id"
end
```

CRUD: Đọc(Reading) và Viết(Writing) Dữ liệu
------------------------------

CRUD là một từ viết tắt của bốn phương thức chúng ta thường sử dụng để thao tác trên dữ liệu: **C**reate,
**R**ead, **U**pdate and **D**elete. Active Record tự động tạo các methods để
cho phép một ứng dụng để đọc và thao tác với dữ liệu được chứa bên trong cách bảng.

### Create

Các objects Active Record có thể được tạo từ một hash, một block hoặc có các
thuộc tính được thiết lập thủ công sau khi tạo. Method `new` sẽ trả về một
object mới trong khi đó method `create` sẽ trả về một object và lưu nó vào trong cơ sở dữ liệu.

Ví dụ, cho một model `User` với các thuộc tính `name` và `occupation`,
method `create` sẽ tạo và lưu một record mới vào cơ sở dữ liệu:

```ruby
user = User.create(name: "David", occupation: "Code Artist")
```

Sử dụng method `new`, một object có thể được khởi tạo nhưng chưa được lưu:

```ruby
user = User.new
user.name = "David"
user.occupation = "Code Artist"
```

Một lời gọi tới `user.save` sẽ lưu record vào cơ sở dữ liệu.

Cuối cùng, nếu một block được cung cấp, cả `create` và `new` sẽ yield
object mới vào block để khởi tạo:

```ruby
user = User.new do |u|
  u.name = "David"
  u.occupation = "Code Artist"
end
```

### Read

Active Record cung cấp rất nhiều API dùng để truy cập dữ liệu bên trong một cơ sở dữ liệu. Bên dưới
là một ít ví dụ về các phương thức truy cập dữ liệu khác nhau được cung cấp bởi Active Record.

```ruby
# trả về một collection với tất cả users
users = User.all
```

```ruby
# trả về user đầu tiên
user = User.first
```

```ruby
# trả về user đầu tiên có name là David
david = User.find_by(name: 'David')
```

```ruby
# tìm tất cả các user có name là David và có occupation là Artists và sắp xếp bởi created_at theo thứ tự giảm dần theo thời gian được tạo
users = User.where(name: 'David', occupation: 'Code Artist').order(created_at: :desc)
```

Bạn có thể học nhiều về truy vấn một Active Record model trong phần hướng dẫn [Active Record
Query Interface](active_record_querying.html).

### Update

Khi nhận một Active Record object, các thuộc tính của nó có thể được sửa đổi và lưu vào cơ sở dữ liệu.

```ruby
user = User.find_by(name: 'David')
user.name = 'Dave'
user.save
```

Một phương pháp rút gọn là dùng hash mapping attribute đối với tên thuộc tính để mô tả giá trị, giống như sau:

```ruby
user = User.find_by(name: 'David')
user.update(name: 'Dave')
```

Phương pháp này hữu ích nhất khi dùng để cập nhật một vài thuộc tính cùng lúc. Nếu bạn muốn
cập nhật một vài records cùng lúc, bạn có thể dùng
`update_all` :

```ruby
User.update_all "max_login_attempts = 3, must_change_password = 'true'"
```

### Delete

Chúng ta có thể hủy một object khỏi cơ sở dữ liệu như sau.

```ruby
user = User.find_by(name: 'David')
user.destroy
```

tương tự như update, nếu bạn muốn xóa một vài records cùng lúc, bạn có thể dùng method `destroy_all` :

```ruby
# tìm và xóa tất cả các user có name là David
User.where(name: 'David').destroy_all

# delete all users
User.destroy_all
```

Xác thực(Validations)
-----------

Active Record cho phép bạn xác thực(validate) trạng thái của một model trước khi nó được lưu
vào cơ sở dữ liệu. Có một vài methods mà bạn có thể dùng để kiểm tra các
models của bạn và validate giá trị của một thuộc tính trong bảng có liệu nó có không rỗng (empty) hay là duy nhất(unique) và không sẵng sàng trong cơ sở dữ liệu, 
theo định dạng và vâng vâng.
Xác thực là một vấn đề rất quan trọng khi thao tác trên cơ sở dữ liệu, 
nên methods `save` và `update` sẽ thực thi
: chúng sẽ trả về `false` khi xác thực fails và chúng không thực sự thực hiện bất kỳ thao tác gì trên cơ sở dữ liệu. 
Nếu các phương thức trên có dấu chấm than (!) (ví dụ: `save!` và `update!`), thì chúng sẽ
gây ra một ngoại lệ `ActiveRecord::RecordInvalid` nếu xác thực thất bại.
Một ví dụ nhanh mô tả vấn đề này:

```ruby
class User < ApplicationRecord
  validates :name, presence: true
end

user = User.new
user.save  # => false
user.save! # => ActiveRecord::RecordInvalid: Validation failed: Name can't be blank
```

Bạn có thể tìm hiểu thêm về validations trong phần [Active Record Validations](active_record_validations.html).

Callbacks
---------

Active Record callbacks cho phép bạn đính kèm mã vào một event nào đó trong
vòng đời của một models nào đó. Điều này cho phép bạn thêm các hành vi vào một models bằng 
cách thực thi code khi các events xảy ra, giống như khi bạn tạo, cập nhật, xóa một record, ... Bạn có thể tìm hiểu thêm về 
callbacks trong phần [Active Record Callbacks](active_record_callbacks.html).

Migrations
----------

Rails cung cấp một miền ngôn ngữ cụ thể dành cho việc quản lý lược đồ cơ sở dữ liệu được gọi là
migrations. Migrations được chứa trong những files đã thực thi đối với bất kỳ
cơ sở dữ liệu nào mà Active Record hỗ trợ dùng `rake`. Đây là migration mà nó tạo ra bảng:

```ruby
class CreatePublications < ActiveRecord::Migration[5.0]
  def change
    create_table :publications do |t|
      t.string :title
      t.text :description
      t.references :publication_type
      t.integer :publisher_id
      t.string :publisher_type
      t.boolean :single_issue

      t.timestamps
    end
    add_index :publications, :publication_type_id
  end
end
```

Rails theo dõi các files đã được committed vào cơ sở dữ liệu và cung cấp tính năng rollback. 
Để thực sự tạo bảng, bạn chạy `rails db:migrate`
và đảo ngược quá trình đó bằng, `rails db:rollback`.

Lưu ý code ở trên là database-agnostic: nó sẽ chạy trong MySQL,
PostgreSQL, Oracle và các hệ cơ sở dữ liệu khác. Bạn có thể tìm hiểu thêm về migrations trong phần
[Active Record Migrations](active_record_migrations.html).
