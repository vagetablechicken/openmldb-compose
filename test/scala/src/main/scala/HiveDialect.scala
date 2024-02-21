import org.apache.spark.sql.jdbc.JdbcDialect

// want to read acid table, but can't do now
object HiveDialect extends JdbcDialect {
  override def canHandle(url : String): Boolean = url.startsWith("jdbc:hive2")
  override def quoteIdentifier(colName: String): String = {
    colName.split('.').map(part => s"`$part`").mkString(".")
  }
}