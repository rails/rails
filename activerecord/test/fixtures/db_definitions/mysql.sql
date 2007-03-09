CREATE TABLE `accounts` (
  `id` int(11) NOT NULL auto_increment,
  `firm_id` int(11) default NULL,
  `credit_limit` int(5) default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `funny_jokes` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(50) default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `companies` (
  `id` int(11) NOT NULL auto_increment,
  `type` varchar(50) default NULL,
  `ruby_type` varchar(50) default NULL,
  `firm_id` int(11) default NULL,
  `name` varchar(50) default NULL,
  `client_of` int(11) default NULL,
  `rating` int(11) default NULL default 1,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;


CREATE TABLE `topics` (
  `id` int(11) NOT NULL auto_increment,
  `title` varchar(255) default NULL,
  `author_name` varchar(255) default NULL,
  `author_email_address` varchar(255) default NULL,
  `written_on` datetime default NULL,
  `bonus_time` time default NULL,
  `last_read` date default NULL,
  `content` text,
  `approved` tinyint(1) default 1,
  `replies_count` int(11) default 0,
  `parent_id` int(11) default NULL,
  `type` varchar(50) default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `developers` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(100) default NULL,
  `salary` int(11) default 70000,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `projects` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(100) default NULL,
  `type` VARCHAR(255) default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `developers_projects` (
  `developer_id` int(11) NOT NULL,
  `project_id` int(11) NOT NULL,
  `joined_on` date default NULL,
  `access_level` smallint default 1
) TYPE=InnoDB;

CREATE TABLE `orders` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(100) default NULL,
  `billing_customer_id` int(11) default NULL,
  `shipping_customer_id` int(11) default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `customers` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(100) default NULL,
  `balance` int(6) default 0,
  `address_street` varchar(100) default NULL,
  `address_city` varchar(100) default NULL,
  `address_country` varchar(100) default NULL,
  `gps_location` varchar(100) default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `movies` (
  `movieid` int(11) NOT NULL auto_increment,
  `name` varchar(100) default NULL,
   PRIMARY KEY  (`movieid`)
) TYPE=InnoDB;

CREATE TABLE `subscribers` (
  `nick` varchar(100) NOT NULL,
  `name` varchar(100) default NULL,
  PRIMARY KEY  (`nick`)
) TYPE=InnoDB;

CREATE TABLE `booleantests` (
  `id` int(11) NOT NULL auto_increment,
  `value` integer default NULL,
  PRIMARY KEY (`id`)
) TYPE=InnoDB;

CREATE TABLE `auto_id_tests` (
  `auto_id` int(11) NOT NULL auto_increment,
  `value` integer default NULL,
  PRIMARY KEY (`auto_id`)
) TYPE=InnoDB;

CREATE TABLE `entrants` (
  `id` INTEGER NOT NULL auto_increment PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `course_id` INTEGER NOT NULL
);

CREATE TABLE `colnametests` (
  `id` int(11) NOT NULL auto_increment,
  `references` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) TYPE=InnoDB;

CREATE TABLE `mixins` (
  `id` int(11) NOT NULL auto_increment,
  `parent_id` int(11) default NULL,
  `pos` int(11) default NULL,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  `lft` int(11) default NULL,
  `rgt` int(11) default NULL,
  `root_id` int(11) default NULL,
  `type` varchar(40) default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `people` (
  `id` INTEGER NOT NULL auto_increment PRIMARY KEY,
  `first_name` VARCHAR(40) NOT NULL,
  `lock_version` INTEGER NOT NULL DEFAULT 0
) TYPE=InnoDB;

CREATE TABLE `readers` (
    `id` int(11) NOT NULL auto_increment PRIMARY KEY,
    `post_id` INTEGER NOT NULL,
    `person_id` INTEGER NOT NULL
) TYPE=InnoDB;

CREATE TABLE `binaries` (
  `id` int(11) NOT NULL auto_increment,
  `data` mediumblob,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `computers` (
  `id` INTEGER NOT NULL auto_increment PRIMARY KEY,
  `developer` INTEGER NOT NULL,
  `extendedWarranty` INTEGER NOT NULL
) TYPE=InnoDB;

CREATE TABLE `posts` (
  `id` INTEGER NOT NULL auto_increment PRIMARY KEY,
  `author_id` INTEGER,
  `title` VARCHAR(255) NOT NULL,
  `body` TEXT NOT NULL,
  `type` VARCHAR(255) default NULL
) TYPE=InnoDB;

CREATE TABLE `comments` (
  `id` INTEGER NOT NULL auto_increment PRIMARY KEY,
  `post_id` INTEGER NOT NULL,
  `body` TEXT NOT NULL,
  `type` VARCHAR(255) default NULL
) TYPE=InnoDB;

CREATE TABLE `authors` (
  `id` INTEGER NOT NULL auto_increment PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL
) TYPE=InnoDB;

CREATE TABLE `tasks` (
  `id` int(11) NOT NULL auto_increment,
  `starting` datetime NOT NULL default '0000-00-00 00:00:00',
  `ending` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `categories` (
  `id` int(11) NOT NULL auto_increment,
  `name` VARCHAR(255) NOT NULL,
  `type` VARCHAR(255) default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `categories_posts` (
  `category_id` int(11) NOT NULL,
  `post_id` int(11) NOT NULL
) TYPE=InnoDB;

CREATE TABLE `fk_test_has_pk` (
  `id` INTEGER NOT NULL auto_increment PRIMARY KEY
) TYPE=InnoDB;

CREATE TABLE `fk_test_has_fk` (
  `id`    INTEGER NOT NULL auto_increment PRIMARY KEY,
  `fk_id` INTEGER NOT NULL,

  FOREIGN KEY (`fk_id`) REFERENCES `fk_test_has_pk`(`id`)
) TYPE=InnoDB;


CREATE TABLE `keyboards` (
  `key_number` int(11) NOT NULL auto_increment primary key,
  `name` varchar(50) default NULL
);

-- Altered lock_version column name.
CREATE TABLE `legacy_things` (
  `id` int(11) NOT NULL auto_increment,
  `tps_report_number` int(11) default NULL,
  `version` int(11) NOT NULL default 0,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `numeric_data` (
  `id` INTEGER NOT NULL auto_increment PRIMARY KEY,
  `bank_balance` decimal(10,2),
  `big_bank_balance` decimal(15,2),
  `world_population` decimal(10),
  `my_house_population` decimal(2),
  `decimal_number_with_default` decimal(3,2) DEFAULT 2.78
) TYPE=InnoDB;

CREATE TABLE mixed_case_monkeys (
 `monkeyID` int(11) NOT NULL auto_increment,
 `fleaCount` int(11),
 PRIMARY KEY (`monkeyID`)
) TYPE=InnoDB;
