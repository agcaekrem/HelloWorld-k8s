FROM openjdk:11
ADD target/spring-boot-hw-0.0.1-SNAPSHOT.jar spring-boot-hw-0.0.1-SNAPSHOT.jar
EXPOSE 8085
ENTRYPOINT ["java","-jar","spring-boot-hw-0.0.1-SNAPSHOT.jar"]
