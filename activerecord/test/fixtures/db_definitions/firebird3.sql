CREATE TABLE taggings (
  id BIGINT NOT NULL,
  tag_id BIGINT,
  super_tag_id BIGINT,
  taggable_type VARCHAR(255),
  taggable_id BIGINT,
  PRIMARY KEY (id)
);
CREATE GENERATOR taggings_seq;
SET GENERATOR taggings_seq TO 10000;

CREATE TABLE tags (
  id BIGINT NOT NULL,
  name VARCHAR(255),
  taggings_count BIGINT DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE GENERATOR tags_seq;
SET GENERATOR tags_seq TO 10000;

CREATE TABLE categorizations (
  id BIGINT NOT NULL,
  category_id BIGINT,
  post_id BIGINT,
  author_id BIGINT,
  PRIMARY KEY (id)
);
CREATE GENERATOR categorizations_seq;
SET GENERATOR categorizations_seq TO 10000;

ALTER TABLE posts ADD taggings_count BIGINT DEFAULT 0;
ALTER TABLE authors ADD author_address_id BIGINT;

CREATE TABLE author_addresses (
  id BIGINT NOT NULL,
  author_address_id BIGINT,
  PRIMARY KEY (id)
);
CREATE GENERATOR author_addresses_seq;
SET GENERATOR author_addresses_seq TO 10000;

CREATE TABLE author_favorites (
  id BIGINT NOT NULL,
  author_id BIGINT,
  favorite_author_id BIGINT,
  PRIMARY KEY (id)
);
CREATE GENERATOR author_favorites_seq;
SET GENERATOR author_favorites_seq TO 10000;
