-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               10.0.32-MariaDB-0+deb8u1 - (Debian)
-- Server OS:                    debian-linux-gnu
-- HeidiSQL Version:             9.5.0.5196
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;


-- Dumping database structure for megamegamonitor
CREATE DATABASE IF NOT EXISTS `megamegamonitor` /*!40100 DEFAULT CHARACTER SET utf8mb4 */;
USE `megamegamonitor`;

-- Dumping structure for table megamegamonitor.accesskeys
DROP TABLE IF EXISTS `accesskeys`;
CREATE TABLE IF NOT EXISTS `accesskeys` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned DEFAULT NULL,
  `secret_key` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `secret_key` (`secret_key`)
) ENGINE=InnoDB AUTO_INCREMENT=46528 DEFAULT CHARSET=latin1;

-- Dumping data for table megamegamonitor.accesskeys: ~8 rows (approximately)
DELETE FROM `accesskeys`;
/*!40000 ALTER TABLE `accesskeys` DISABLE KEYS */;
INSERT INTO `accesskeys` (`id`, `user_id`, `secret_key`, `created_at`, `updated_at`) VALUES
	(1781, 4226, 'SAMPLE SECRET KEY 1781', '2016-04-14 22:07:03', '2016-04-14 22:07:03'),
	(43571, 4226, 'SAMPLE SECRET KEY 43571', '2017-05-29 20:14:10', '2017-05-29 20:14:10'),
	(45414, 4226, 'SAMPLE SECRET KEY 45414', '2018-02-08 18:29:42', '2018-02-08 18:29:42'),
	(45421, 4226, 'SAMPLE SECRET KEY 45421', '2018-02-08 18:36:17', '2018-02-08 18:36:17'),
	(45465, 4226, 'SAMPLE SECRET KEY 45465', '2018-02-08 20:04:17', '2018-02-08 20:04:17'),
	(45768, 4226, 'SAMPLE SECRET KEY 45768', '2018-02-11 22:12:34', '2018-02-11 22:12:34'),
	(45772, 4226, 'SAMPLE SECRET KEY 45772', '2018-02-12 00:14:55', '2018-02-12 00:14:55'),
	(45773, 4226, 'SAMPLE SECRET KEY 45773', '2018-02-12 00:16:53', '2018-02-12 00:16:53');
/*!40000 ALTER TABLE `accesskeys` ENABLE KEYS */;

-- Dumping structure for table megamegamonitor.accounts
DROP TABLE IF EXISTS `accounts`;
CREATE TABLE IF NOT EXISTS `accounts` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;

-- Dumping data for table megamegamonitor.accounts: ~1 rows (approximately)
DELETE FROM `accounts`;
/*!40000 ALTER TABLE `accounts` DISABLE KEYS */;
INSERT INTO `accounts` (`id`, `username`, `password`, `created_at`, `updated_at`) VALUES
	(2, 'MegaMegaMonitorBot', 'MegaMegaMonitorBot\'s password (not really this)', '2015-04-07 16:50:15', '2015-04-07 16:50:15');
/*!40000 ALTER TABLE `accounts` ENABLE KEYS */;

-- Dumping structure for table megamegamonitor.contributors
DROP TABLE IF EXISTS `contributors`;
CREATE TABLE IF NOT EXISTS `contributors` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned DEFAULT NULL,
  `subreddit_id` int(11) DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `tooltip_suffix` varchar(255) DEFAULT NULL,
  `display_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id_and_subreddit_id_unique` (`user_id`,`subreddit_id`) USING BTREE,
  KEY `subreddit_id` (`subreddit_id`)
) ENGINE=InnoDB AUTO_INCREMENT=365175 DEFAULT CHARSET=latin1;

-- Dumping data for table megamegamonitor.contributors: ~2 rows (approximately)
DELETE FROM `contributors`;
/*!40000 ALTER TABLE `contributors` DISABLE KEYS */;
INSERT INTO `contributors` (`id`, `user_id`, `subreddit_id`, `date`, `created_at`, `updated_at`, `tooltip_suffix`, `display_name`) VALUES
	(200312, 5872, 85, '2015-04-09 21:20:52', '2016-03-23 20:56:43', '2016-03-23 20:56:43', NULL, 'MegaMegaMonitorBot'),
	(200330, 4226, 85, '2013-12-14 01:16:58', '2016-03-23 20:56:44', '2016-03-23 20:56:44', NULL, 'Greypo');
/*!40000 ALTER TABLE `contributors` ENABLE KEYS */;

-- Dumping structure for table megamegamonitor.cryptokeys
DROP TABLE IF EXISTS `cryptokeys`;
CREATE TABLE IF NOT EXISTS `cryptokeys` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `subreddit_id` int(10) unsigned DEFAULT NULL,
  `secret_key` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `subreddit_id` (`subreddit_id`)
) ENGINE=InnoDB AUTO_INCREMENT=319 DEFAULT CHARSET=latin1;

-- Dumping data for table megamegamonitor.cryptokeys: ~6 rows (approximately)
DELETE FROM `cryptokeys`;
/*!40000 ALTER TABLE `cryptokeys` DISABLE KEYS */;
INSERT INTO `cryptokeys` (`id`, `subreddit_id`, `secret_key`, `created_at`, `updated_at`) VALUES
	(161, 85, 'ORIGINAL CRYPTOKEY FOR MEGALOUNGE2', '2015-04-10 08:10:33', '2015-04-10 08:10:33'),
	(215, 85, 'SECOND CRYPTOKEY FOR MEGALOUNGE2', '2015-05-26 10:01:47', '2015-05-26 10:01:47'),
	(276, 85, 'THIRD CRYPTOKEY FOR MEGALOUNGE2', '2016-01-05 12:30:35', '2016-01-05 12:30:35');
/*!40000 ALTER TABLE `cryptokeys` ENABLE KEYS */;

-- Dumping structure for table megamegamonitor.gildings
DROP TABLE IF EXISTS `gildings`;
CREATE TABLE IF NOT EXISTS `gildings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `kind` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `subreddit_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `url` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `created_utc` bigint(20) DEFAULT NULL,
  `gilded` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `subreddit_id` (`subreddit_id`)
) ENGINE=InnoDB AUTO_INCREMENT=20496 DEFAULT CHARSET=latin1;

-- Dumping data for table megamegamonitor.gildings: ~0 rows (approximately)
DELETE FROM `gildings`;
/*!40000 ALTER TABLE `gildings` DISABLE KEYS */;
/*!40000 ALTER TABLE `gildings` ENABLE KEYS */;

-- Dumping structure for table megamegamonitor.schema_migrations
DROP TABLE IF EXISTS `schema_migrations`;
CREATE TABLE IF NOT EXISTS `schema_migrations` (
  `version` varchar(255) NOT NULL,
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table megamegamonitor.schema_migrations: ~6 rows (approximately)
DELETE FROM `schema_migrations`;
/*!40000 ALTER TABLE `schema_migrations` DISABLE KEYS */;
INSERT INTO `schema_migrations` (`version`) VALUES
	('20151014121927'),
	('20151125112639'),
	('20151125112650'),
	('20151125112656'),
	('20151125135217'),
	('20151215112417');
/*!40000 ALTER TABLE `schema_migrations` ENABLE KEYS */;

-- Dumping structure for table megamegamonitor.subreddits
DROP TABLE IF EXISTS `subreddits`;
CREATE TABLE IF NOT EXISTS `subreddits` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `display_name` varchar(255) DEFAULT NULL,
  `override_display_name` varchar(255) DEFAULT NULL,
  `chain_number` int(10) unsigned DEFAULT NULL,
  `spriteset_position` int(10) unsigned DEFAULT NULL,
  `monitor_contributors` tinyint(1) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `user_list_updated_at` datetime DEFAULT NULL,
  `name_is_secret` tinyint(1) NOT NULL DEFAULT '0',
  `crypto` varchar(255) DEFAULT NULL,
  `access_secret` varchar(255) DEFAULT NULL,
  `account_id` int(10) unsigned NOT NULL,
  `monitor_gildings` tinyint(4) NOT NULL DEFAULT '0',
  `gildings_updated_at` datetime DEFAULT NULL,
  `icon_default_file_name` varchar(255) DEFAULT NULL,
  `icon_default_content_type` varchar(255) DEFAULT NULL,
  `icon_default_file_size` int(11) DEFAULT NULL,
  `icon_default_updated_at` datetime DEFAULT NULL,
  `icon_current_file_name` varchar(255) DEFAULT NULL,
  `icon_current_content_type` varchar(255) DEFAULT NULL,
  `icon_current_file_size` int(11) DEFAULT NULL,
  `icon_current_updated_at` datetime DEFAULT NULL,
  `icon_higher_file_name` varchar(255) DEFAULT NULL,
  `icon_higher_content_type` varchar(255) DEFAULT NULL,
  `icon_higher_file_size` int(11) DEFAULT NULL,
  `icon_higher_updated_at` datetime DEFAULT NULL,
  `encoded_icon_default` varchar(16384) DEFAULT NULL,
  `encoded_icon_current` varchar(16384) DEFAULT NULL,
  `encoded_icon_higher` varchar(16384) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=181 DEFAULT CHARSET=latin1;

-- Dumping data for table megamegamonitor.subreddits: ~1 rows (approximately)
DELETE FROM `subreddits`;
/*!40000 ALTER TABLE `subreddits` DISABLE KEYS */;
INSERT INTO `subreddits` (`id`, `name`, `display_name`, `override_display_name`, `chain_number`, `spriteset_position`, `monitor_contributors`, `created_at`, `updated_at`, `user_list_updated_at`, `name_is_secret`, `crypto`, `access_secret`, `account_id`, `monitor_gildings`, `gildings_updated_at`, `icon_default_file_name`, `icon_default_content_type`, `icon_default_file_size`, `icon_default_updated_at`, `icon_current_file_name`, `icon_current_content_type`, `icon_current_file_size`, `icon_current_updated_at`, `icon_higher_file_name`, `icon_higher_content_type`, `icon_higher_file_size`, `icon_higher_updated_at`, `encoded_icon_default`, `encoded_icon_current`, `encoded_icon_higher`) VALUES
	(85, '2zf3d', 'MegaLounge2', NULL, NULL, 73, 1, '2015-04-09 22:14:35', '2018-05-18 23:00:52', '2018-05-18 23:00:52', 0, NULL, '9464a3776c576357f242df8d4d90a4c1', 2, 0, NULL, '85-0.png', 'image/png', 1582, '2015-11-25 11:58:15', '85-1.png', 'image/png', 1501, '2015-11-25 11:58:15', '85-1.png', 'image/png', 1501, '2015-11-25 11:58:15', 'data:image/png;base64,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', 'data:image/png;base64,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', 'data:image/png;base64,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');
/*!40000 ALTER TABLE `subreddits` ENABLE KEYS */;

-- Dumping structure for table megamegamonitor.users
DROP TABLE IF EXISTS `users`;
CREATE TABLE IF NOT EXISTS `users` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `display_name` varchar(255) DEFAULT NULL,
  `installation_seen_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `ninja_pirate_visible` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `display_name` (`display_name`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=155126 DEFAULT CHARSET=latin1;

-- Dumping data for table megamegamonitor.users: ~2 rows (approximately)
DELETE FROM `users`;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` (`id`, `name`, `display_name`, `installation_seen_at`, `created_at`, `updated_at`, `ninja_pirate_visible`) VALUES
	(4226, 't2_9zpxz', 'Greypo', '2018-05-29 05:28:49', '2016-03-23 19:33:31', '2018-02-11 22:13:04', 0),
	(5872, 't2_kt1lt', 'MegaMegaMonitorBot', NULL, '2016-03-23 19:37:56', '2016-03-23 19:37:56', 0);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
