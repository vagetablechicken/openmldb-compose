create database db;
use db;
CREATE TABLE db.user (ubb_gaid string, std_time TIMESTAMP, INDEX(KEY=ubb_gaid, ttl_type=latest, ttl=1)) OPTIONS(partitionnum=10, replicanum=1, storage_mode='HDD');
-- event是请求主表，空着应该没关系
CREATE TABLE db.event (uuid string, gaid string, game_id string, std_time TIMESTAMP, INDEX(KEY=uuid),INDEX(KEY=gaid),INDEX(KEY=game_id)) OPTIONS(partitionnum=10, replicanum=1, storage_mode='HDD');
CREATE TABLE db.game (ibb_id string, std_time TIMESTAMP, INDEX(KEY=ibb_id, ttl_type=latest, ttl=1)) OPTIONS(partitionnum=10, replicanum=1, storage_mode='HDD');
set @@execute_mode='online';
DEPLOY fs_test_v1 
SELECT
  *
FROM
  event
LAST JOIN
  user
ON 
  event.gaid = user.ubb_gaid
LAST JOIN
  game
ON event.game_id = game.ibb_id
;

