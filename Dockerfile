FROM openjdk:8-jdk-alpine
MAINTAINER RamaGopal <ram.devops0909@gmail.com>
EXPOSE 8086
COPY jenkins-cicd-k8s-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]