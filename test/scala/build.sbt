name := "Simple Project"

version := "1.0"

scalaVersion := "2.12.15"

libraryDependencies += "org.apache.spark" %% "spark-sql" % "3.2.1"

resolvers += Resolver.mavenLocal
resolvers += Resolver.bintrayRepo("hseeberger", "maven")
resolvers += "Sonatype OSS Snapshots" at "https://oss.sonatype.org/content/repositories/snapshots"
// 将阿里云仓库做为默认仓库
externalResolvers := List("my repositories" at "https://maven.aliyun.com/nexus/content/groups/public/")
