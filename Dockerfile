FROM openjdk:11
COPY target/Hello-World-k8s-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar"]

