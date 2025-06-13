# Dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Java and basic tools
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk curl gnupg2 git && \
    rm -rf /var/lib/apt/lists/*

# Add Jenkins repo
RUN curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null && \
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
RUN apt-get update && apt-get install -y jenkins

EXPOSE 8080 

CMD ["java", "-jar", "/usr/share/jenkins/jenkins.war"]
