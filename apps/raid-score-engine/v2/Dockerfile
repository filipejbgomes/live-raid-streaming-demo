FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
COPY src src
RUN --mount=type=cache,target=/root/.m2 mvn -B -ntp package
FROM flink:1.20.1-scala_2.12-java17
RUN mkdir -p /opt/flink/plugins/s3-fs-hadoop && cp /opt/flink/opt/flink-s3-fs-hadoop-*.jar /opt/flink/plugins/s3-fs-hadoop/
COPY --from=build /build/target/bossraid.jar /opt/flink/usrlib/bossraid.jar
ENV JOB_VERSION=v2
