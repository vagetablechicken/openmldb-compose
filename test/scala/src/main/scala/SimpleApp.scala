/* SimpleApp.scala */
import org.apache.spark.sql.SparkSession

object SimpleApp {
  def main(args: Array[String]) {
    val spark = SparkSession.builder.appName("Simple Application").getOrCreate()
    spark.sparkContext.setLogLevel("INFO")
    println(spark.sessionState.catalog.listDatabases)
    spark.sql("show namespaces;").show()
    spark.sql("show tables from nyc_ice_hive;").show()
    spark.sql("select * from nyc_ice_hive.taxis").show()
    // spark.sql("show namespaces from hadoop_prod;").show()
    spark.stop()
  }
}
