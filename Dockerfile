FROM openjdk:8-jdk-alpine
MAINTAINER RamaGopal <ram.devops0909@gmail.com>
EXPOSE 8080
COPY helloworld.jar app.jar
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
