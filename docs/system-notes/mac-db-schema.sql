
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `isrstamps` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `isrstamps`;
DROP TABLE IF EXISTS `urlmap`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `urlmap` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ctime` char(8) NOT NULL,
  `size-remsize` char(15) NOT NULL,
  `flags` char(6) NOT NULL,
  `statusCode` int(11) NOT NULL,
  `statusMessage` char(40) NOT NULL,
  `MIME` char(20) NOT NULL,
  `etagOrDate` char(80) NOT NULL,
  `URL` char(80) NOT NULL,
  `localfile` varchar(2048) NOT NULL,
  `fromURL` char(80) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `URLindex` (`URL`)
) ENGINE=MyISAM AUTO_INCREMENT=58105 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Imported from HTTRACK mirror new.txt file as TSV.';
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `urlmap.js`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `urlmap.js` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ctime` char(8) NOT NULL,
  `size-remsize` char(15) NOT NULL,
  `flags` char(6) NOT NULL,
  `statusCode` int(11) NOT NULL,
  `statusMessage` char(40) NOT NULL,
  `MIME` char(40) NOT NULL,
  `etagOrDate` char(80) NOT NULL,
  `URL` varchar(128) NOT NULL,
  `localfile` varchar(2048) NOT NULL,
  `fromURL` varchar(128) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `URLindex` (`URL`)
) ENGINE=MyISAM AUTO_INCREMENT=600 DEFAULT CHARSET=utf8 COMMENT='Imported from HTTRACK mirror new.txt file as TSV.';
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `urlmap.new`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `urlmap.new` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ctime` char(8) NOT NULL,
  `size-remsize` char(15) NOT NULL,
  `flags` char(6) NOT NULL,
  `statusCode` int(11) NOT NULL,
  `statusMessage` char(40) NOT NULL,
  `MIME` char(20) NOT NULL,
  `etagOrDate` char(80) NOT NULL,
  `URL` varchar(128) NOT NULL,
  `localfile` varchar(2048) NOT NULL,
  `fromURL` varchar(128) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `URLindex` (`URL`)
) ENGINE=MyISAM AUTO_INCREMENT=1262 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Imported from HTTRACK mirror new.txt file as TSV.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

