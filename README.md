First  make  directory jenkins-project
mkdir  -p  jenkins-project
-----------------------------
create  a docker file  for  jenkins-master image 

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

EXPOSE 8080 50000

CMD ["/usr/bin/jenkins"]

-----------
create jenkins-agent directory  under  jenkins-project

ssh-keygen -t rsa -b 4096 -f jenkins_agent_key -N ""
This generates:

jenkins_agent_key (private)

jenkins_agent_key.pub (public)

Note :-  it  is important folder  where  agent dockerfile is there  need  to  be ssh puublic  and private  key should be present as  it  created images  adding ssh key on it.

again create dockerfile for  jenkins-agent images which have open-ssh server in it .

FROM debian:bullseye

# Install dependencies
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Create Jenkins user
RUN useradd -m -s /bin/bash jenkins

# Setup SSH
RUN mkdir /home/jenkins/.ssh
COPY jenkins_agent_key.pub /home/jenkins/.ssh/authorized_keys
RUN chown -R jenkins:jenkins /home/jenkins/.ssh && chmod 700 /home/jenkins/.ssh && chmod 600 /home/jenkins/.ssh/authorized_keys

# Start SSH on container start
RUN mkdir /var/run/sshd
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]

----------------
again create Deploy Agent Pod to Kubernetes jenkins-agent.yaml

apiVersion: v1
kind: Pod
metadata:
  name: jenkins-agent
  labels:
    app: jenkins-agent
spec:
  containers:
  - name: jenkins-agent
    image: your-registry/jenkins-agent
    ports:
    - containerPort: 22
    volumeMounts:
    - name: ssh-volume
      mountPath: /home/jenkins/.ssh
  volumes:
  - name: ssh-volume
    emptyDir: {}

-----------
again create service yaml for  pod

apiVersion: v1
kind: Service
metadata:
  name: jenkins-agent-ssh
spec:
  selector:
    app: jenkins-agent   # Make sure this matches your pod's label
  ports:
    - protocol: TCP
      port: 22           # Service port (inside cluster)
      targetPort: 22     # Container's SSH port
      nodePort: 32222    # External port on Minikube node (choose any 30000-32767)
  type: NodePort

-----------

Deployment  stages

docker build -t custom-jenkins-master .
docker run -d -p 8080:8080 --name jenkins-master custom-jenkins-master

docker build -t custom-jenkins-agent .

kubectl apply -f jenkins-agent.yaml

kubectl apply -f service.yaml

------------------------
configuration  stages 

docker  run --network=host -d  --name jenkins-master ashu304/lite-jenkins

login  as jenkins  as http://localhost:8080

docker exec -it jenkins-master mkdir -p /home/jenkins/.ssh

#setting  file  permission

docker exec -it jenkins-master chmod 700 /home/jenkins/.ssh

docker cp jenkins_agent_key jenkins-master:/home/jenkins/.ssh/jenkins_agent_key

docker exec -it jenkins-master chmod 600 /home/jenkins/.ssh/jenkins_agent_key

# Copying  and  verifying ssh public key on minikube  side



kubectl exec -it jenkins-agent -- bash

kubectl cp jenkins_agent_key.pub jenkins-agent:/home/jenkins/.ssh/authorized_keys

# setting permission

chown -R jenkins:jenkins /home/jenkins/.ssh

chmod 700 /home/jenkins/.ssh

chmod 600 /home/jenkins/.ssh/authorized_keys

cat /etc/ssh/sshd_config | grep -Ei 'PubkeyAuthentication|AuthorizedKeysFile|PasswordAuthentication'

#change  setting in configuration

sed -i 's/#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's|#\?AuthorizedKeysFile.*|AuthorizedKeysFile .ssh/authorized_keys|' /etc/ssh/sshd_config
sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

it  should be like 

'''
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
'''

kill -HUP 1  #  restart sshd with  new  config

#  Testing  phase

login into  docker container  on  jenkins-master and drag to  folder  where ssh private  key is  present

command :- ssh -i path/to/jenkins_agent_key -p 32222 jenkins@minikube-ip

successfully  login  comes!

# Build phase 

login  into jenkins web ui --> Go to Manage Jenkins → Nodes → New Node

Select "Permanent Agent"

labels:  "minikube"

Set:

Remote root directory: /home/jenkins

Launch method: Launch agents via SSH

Host: minikube-ip

Port: 32222

Credentials: Add the private key (jenkins_agent_key)

save


# Testing 

make  new pipeline for testing  

pipeline {
    agent { label 'minikube' } // Replace 'minikube' with your agent's label or name
    stages {
        stage('Test Agent') {
            steps {
                echo 'Hello from Jenkins pipeline!'
                sh 'hostname'
            }
        }
    }
}


Check  output  on consoleoutput.





