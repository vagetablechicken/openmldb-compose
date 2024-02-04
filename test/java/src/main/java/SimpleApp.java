/* SimpleApp.java */
import org.apache.spark.sql.SparkSession;
import org.apache.spark.sql.Dataset;


public class SimpleApp {
  public static void main(String[] args) {
    SparkSession spark = SparkSession.builder().appName("Simple Application").getOrCreate();
    System.out.println(spark.sessionState().catalog());
    spark.sql("show namespaces;").show();
    // spark.sql("show namespaces from hive_prod;").show();
    // spark.sql("show tables from hive_prod.session_catalog_test").show();
    spark.stop();
  }
}

