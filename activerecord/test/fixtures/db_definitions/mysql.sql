CREATE TABLE `accounts` (
  `id` int(11) NOT NULL auto_increment,
  `firm_id` int(11) default NULL,
  `credit_limit` int(5) default NULL,
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
  `last_read` date default NULL,
  `content` text,
  `approved` tinyint(1) default 1,
  `replies_count` int(11) default 0,
  `parent_id` int(11) default NULL,
  `type` varchar(50) default NULL,
  PRIMARY KEY  (`id`)
) TYPE=InnoDB;

CREATE TABLE `developers` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(100) default NULL,
  PRIMARY KEY  (`id`)
);

CREATE TABLE `projects` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(100) default NULL,
  PRIMARY KEY  (`id`)
);

CREATE TABLE `developers_projects` (
  `developer_id` int(11) NOT NULL,
  `project_id` int(11) NOT NULL
);

CREATE TABLE `customers` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(100) default NULL,
  `balance` int(6) default 0,
  `address_street` varchar(100) default NULL,
  `address_city` varchar(100) default NULL,
  `address_country` varchar(100) default NULL,
  PRIMARY KEY  (`id`)
);

CREATE TABLE `movies` (
  `movieid` int(11) NOT NULL auto_increment,
  `name` varchar(100) default NULL,
   PRIMARY KEY  (`movieid`)
);

CREATE TABLE `subscribers` (
  `nick` varchar(100) NOT NULL,
  `name` varchar(100) default NULL,
  PRIMARY KEY  (`nick`)
);

CREATE TABLE `booleantests` (
  `id` int(11) NOT NULL auto_increment,
  `value` integer default NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `auto_id_tests` (
  `auto_id` int(11) NOT NULL auto_increment,
  `value` integer default NULL,
  PRIMARY KEY (`auto_id`)
);

CREATE TABLE `entrants` (
  `id` INTEGER NOT NULL PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `course_id` INTEGER NOT NULL
);

CREATE TABLE `colnametests` (
  `id` int(11) NOT NULL auto_increment,
  `references` int(11) NOT NULL,
  PRIMARY KEY (`id`)
);
