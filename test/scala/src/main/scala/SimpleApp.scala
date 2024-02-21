/* SimpleApp.scala */
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.jdbc.JdbcDialects

object SimpleApp {
  def main(args: Array[String]): Unit = {
    JdbcDialects.registerDialect(HiveDialect)
    val spark = SparkSession.builder.appName("Simple Application").getOrCreate()
    spark.sparkContext.setLogLevel("INFO")
    println(spark.sessionState.catalog.listDatabases)
    spark.sql("show namespaces;").show()
    spark.sql("show tables;").show()
    // spark.sql("select * from nyc_ice_hive.taxis").show()
    // spark.sql("show namespaces from hadoop_prod;").show()
    // acid table needs hive conf about txn, set it in hive-site.xml
    // val df = spark.read.format("jdbc").option("driver", "org.apache.hive.jdbc.HiveDriver")
    // // configuration variable
    // // jdbc:hive2://<host1>:<port1>,<host2>:<port2>/dbName;initFile=<file>;sess_var_list?hive_conf_list#hive_var_list, it should be the hive_conf_list
    //   // .option("url", "jdbc:hive2://hiveserver2:10000/;?hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager") // it's right url, you can check `set;` on beeline, but org.apache.hive.service.cli.HiveSQLException: Error running query
    //   // .option("hive.txn.manager", "org.apache.hadoop.hive.ql.lockmgr.DbTxnManager")
    //   .option("dbtable", "basic_test.acid").load() // .option("user", "USER").option("password", "PWD").option("fetchsize","20").load()
    // df.show()
    spark.stop()
  }
}
