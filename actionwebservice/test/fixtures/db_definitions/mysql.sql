CREATE TABLE `users` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(30) default NULL,
  `active` tinyint(4) default NULL,
  `created_on` date default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
