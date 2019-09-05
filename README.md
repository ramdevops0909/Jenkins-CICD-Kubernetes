# Kubernetes zero downtime Deployment Using Jenkins Pipeline

Deploying (zero downtime deployment) the Spring boot Application(jenkins-cicd-k8s-0.0.1-SNAPSHOT.jar) in Kubernetes Google cloud cluster environment using Jenkins CI/CD Pipeline
Using Jenkins Pipe line, I have performed following steps to achieve this requirement

```
      	1) Created following Global Credentials in Jenkins Console
			Github Credentials : For SCM checkout purpose
			Docker-registry Credentials : For publishing the docker images to docker-registry (private registry)
			Jenkins Credentials: Used for communication with docker
			Kubeconfig Credentials : Used for communication with Kubernetes
	2) Created Jfrog Artifactory for storing the Jar files (Artifacts like jar, war etc...)
		        Updated Jfrog required detais in Jenkins console (Manage Jenkins --> Configure System)
			   serverid, URL and Jfrog credentials
	3) Created the Dockerfile and dockerized the jenkins-cicd-k8s-0.0.1-SNAPSHOT.jar file
        4) Build the image and published the image into docker registry and removed unused docker  images
        5) Prepared the zero downtime Kubernetes deployment,service yml files (Including liveness and readines probes) for creation of K8S Infrastructure using Jenkins Pipeline
	
```

Dockerfile:
----------
   Using Dockerfile, I am able to dockerize the helloworld microservice

	```
	FROM openjdk:8-jdk-alpine
	MAINTAINER RamaGopal <ram.devops0909@gmail.com>
	EXPOSE 8086
	COPY jenkins-cicd-k8s-0.0.1-SNAPSHOT.jar app.jar
	ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]

	```
helloworld-k8s-service.yml:
---------------------------
Below is the helloworld kubernetes service yml file. Using following deployment.yaml file we can spinup 3 pods. 
Successfully deployed (zero downtime - rolling update on Kubernetes cluser) above dockerized microservice into 
google cloud kubernetes cluster environment ( its has 3 nodes ( kubemaster,kubenode-1,kubenode-2))

Using service we can access Helloworld application using loadbancer IP address with port "8080"

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-deployment
spec:
  replicas: 3
  minReadySeconds: 30
  selector:
    matchLabels:
      app: hello-world-k8s
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: hello-world-k8s
    spec:
      containers:
      - name: hello-world-k8s
        image: jenkins-kubernetes:$BUILD_NUMBER
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 10
          timeoutSeconds: 1
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 10
          timeoutSeconds: 1
      imagePullSecrets:
      - name: registry-secret
---
kind: Service
apiVersion: v1
metadata:
  name:  hello-world-service
spec:
  selector:
    app:  hello-world-k8s
  type:  LoadBalancer
  ports:
  - name:  http
    port:  8080
    protocol: TCP

```
```
Even I tried to access the Application using Node port as well. In order to access the application using NodePort from out side the Kubernetes cluster,
I have enabeld the the firewall for the perticular port using below command

C:\Program Files (x86)\Google\Cloud SDK>gcloud compute firewall-rules create my-rule-k8s --allow=tcp:30005
Creating firewall...\Created [https://www.googleapis.com/compute/v1/projects/cohesive-ridge-226016/global/firewalls/my-rule-k8s].
Creating firewall...done.
NAME         NETWORK  DIRECTION  PRIORITY  ALLOW      DENY  DISABLED
my-rule-k8s  default  INGRESS    1000      tcp:30005        False

Once enabled port (30005) ,I was able to access the application using this URL (http://Node_public_ip:30005)

kind: Service
apiVersion: v1
metadata:
  name:  hello-world-service
spec:
  selector:
    app:  hello-world-k8s
  type:  NodePort
  ports:
  - name:  http
    port:  8080
    nodePort: 30005
    protocol: TCP

```
```
Creating the docker-registry secret:

kubectl \
create secret docker-registry registry-secret \
--docker-server=https://10.142.0.5:5000/ \
--docker-username=admin \
--docker-password=xxxxxx \
--docker-email=ram.devops0909@gmail.com

secret/registry-secret created

```

```
Jenkinsfile:
------------
Below Jenkins file would perform following stages

	1) SCM CHECKOUT - It will clone the source code from the Github Repository
	2) Build the Artifact - Using maven it will create the artifacts (jar or war files)
	3) Upload the artifacts - Once it build the artifacts , it will be uploaded to Jfrog Artifactory
	            Installed Jfrog container in my google cloud environment and started the service
	            Updated Jfrog required detais in Jenkins console (Manage Jenkins --> Configure System)
					Server ID : jfrog-titan
					URL: http://35.237.212.158:8081/artifactory
					Jfrog credentials
					
	4) Docker Image Build - Jenkins pipeline would read the Dockerfile and dockerize the Jar file 
	5) Docker Tag Build : Tagging the docker Image
	6) Docker Publish : Uploading the docker images in to docker-registry (private registry)
	7) DeployToK8SCluster : Above Dockerize application would be deployed in kubernetes cluster environment (helloworld-k8s-service.yml).
	

pipeline
	{
  environment {
    build_branch = 'master'
    repo_name = 'Jenkins-CICD-Kubernetes'
    target = '/root/.m2/repository/'
    jfrog_repo_name = 'hexad-repo'
    }
		agent { label 'master' }
		stages
		{
			stage('SCM CHECKOUT')
			{
				steps
				{
					echo env.build_branch + 'master'
					echo env.repo_name + "Jenkins-CICD-Kubernetes"
					git changelog: false, credentialsId: '49bb929a-8c7b-4977-8806-90ba82e03180', poll: true, url: "https://github.com/ramdevops0909/${env.repo_name}.git", branch: env.build_branch

				}
			}

			stage('Build the artifact')
			{
				steps
				{
					sh '/usr/bin/mvn clean install -DskipTests=true'
				}
			}
			stage('upload artifact to artifactory')
			{
				steps
				{
					script
					{
						pom = readMavenPom file: 'pom.xml'
						echo pom.version
						echo pom.artifactId
						echo pom.packaging
					    echo env.target

						def server = Artifactory.server 'jfrog-titan'
						def uploadSpec = """{
						"files": [
						{
							"pattern": "/root/.m2/repository/*.jar",
							"target": "${env.jfrog_repo_name}/"
						}
						]
						}"""
						server.upload(uploadSpec)
					}
				}
			}

			stage('Docker Image Build')
			{
				steps
				{
					    script
						{
							sh "hostname"
							sh "pwd"

						    pom = readMavenPom file: 'pom.xml'
							echo pom.version
							echo pom.artifactId
							echo pom.packaging

							sh "docker build -f /root/.m2/repository/Dockerfile -t jenkins-kubernetes:${BUILD_NUMBER} --no-cache ."
						}
				}
			}
			stage('Docker Tag Build')
			{
				steps
				{
						sh "docker tag jenkins-kubernetes:${BUILD_NUMBER} 10.142.0.5:5000/jenkins-kubernetes:${BUILD_NUMBER}"

				}
			}
			stage('Docker Publish')
			{
				steps
				{
					timestamps
					{
						withDockerRegistry([credentialsId: 'b0bbb92b-38f9-48e4-a1fb-6b95a2f43cc7', url: 'https://10.142.0.5:5000'])
						{
							sh "docker push 10.142.0.5:5000/jenkins-kubernetes:${BUILD_NUMBER}"
						}
					}
				}
			}
			stage('DeployToK8SCluster') {
            steps {
                kubernetesDeploy(
                    kubeconfigId: 'kubeconfig',
                    configs: 'helloworld-k8s-service.yml',
                    enableConfigSubstitution: true
                )
            }
        }
		}
	}


```

```
In order to access above deployed helloworld micro service, we need to use this URL `http://<Loadbalancer>:<<port>>` in your browser, you should be able to see as below .....

	Hello World!!
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

docker-registry Installation:
-----------------------------

1) Setup a self signed certificate
	root@kubemaster:/# mkdir -p docker_reg_certs
	root@kubemaster:/# openssl req  -newkey rsa:4096 -nodes -sha256 -keyout /docker_reg_certs/domain.key -x509 -days 365 -out /docker_reg_certs/domain.crt
		Generating a 4096 bit RSA private key
		......................................................................++
		.......................................................................................................................................................................................++
		writing new private key to '/docker_reg_certs/domain.key'
		-----
		You are about to be asked to enter information that will be incorporated
		into your certificate request.
		What you are about to enter is what is called a Distinguished Name or a DN.
		There are quite a few fields but you can leave some blank
		For some fields there will be a default value,
		If you enter '.', the field will be left blank.
		-----
		Country Name (2 letter code) [AU]:
		State or Province Name (full name) [Some-State]:
		Locality Name (eg, city) []:
		Organization Name (eg, company) [Internet Widgits Pty Ltd]:
		Organizational Unit Name (eg, section) []:
		Common Name (e.g. server FQDN or YOUR name) []:10.142.0.5
		Email Address []:

2) Installation of the certificates

		root@kubemaster:/# mkdir -p /etc/docker/certs.d/10.142.0.5:5000
		root@kubemaster:/# cp /docker_reg_certs/domain.crt /etc/docker/certs.d/10.142.0.5:5000/ca.crt
		root@kubemaster:/# cp /docker_reg_certs/domain.crt /usr/local/share/ca-certificates/ca.crt
		root@kubemaster:/# update-ca-certificates
		Updating certificates in /etc/ssl/certs...
		1 added, 0 removed; done.
		Running hooks in /etc/ca-certificates/update.d...

		Adding debian:ca.pem
		done.
		done.
3) Add user authentication for registry access and Use htpasswd to create username and associated password

		root@kubemaster:/# mkdir docker_reg_auth
		root@kubemaster:/# docker run -it --entrypoint htpasswd -v $PWD/docker_reg_auth:/auth -w /auth registry:2 -Bbc /auth/htpasswd admin password
		Adding password for user admin

4) Restart docker service:		
		root@kubemaster:/# systemctl restart dockerr

5) Start registry service with the new config:

		root@kubemaster:/# docker run -d -p 5000:5000 --restart=always --name registry -v $PWD/docker_reg_certs:/certs -v $PWD/docker_reg_auth:/auth -v /reg:/var/lib/registry -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -e REGISTRY_AUTH=htpasswd registry:2
		995641adea197f47f8f2e9f3bbf88405e23540cb28c264245f05ecef023b641e
		
6) Login docker registry using below credentials

	root@kubemaster:/# docker login -uadmin -ppassword 10.142.0.5:5000
	WARNING! Using --password via the CLI is insecure. Use --password-stdin.
	WARNING! Your password will be stored unencrypted in /home/annap/.docker/config.json.
	Configure a credential helper to remove this warning. See
	https://docs.docker.com/engine/reference/commandline/login/#credentials-store

	Login Succeeded
	
	root@kubemaster:~/YAML# docker push 10.142.0.5:5000/jenkins-kubernetes:50
		The push refers to repository [10.142.0.5:5000/jenkins-kubernetes]
		55fc7daf2f68: Layer already exists
		ec2000da9365: Layer already exists
		ceaf9e1ebef5: Layer already exists
		9b9b7f3d56a0: Layer already exists
		f1b5933fe4b5: Layer already exists
		50: digest: sha256:33d657031443a8517366a6acafcaac96b3ddb97b2ca4b659db6c46ed0831cc8a size: 1366
		
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Install JFrog Artifactory on Ubuntu 18.04:
------------------------------------------
1) Already installed docker in my google cloud kubemaster server

2) Download JFrog Artifactory Docker image

	root@kubemaster:~# docker pull docker.bintray.io/jfrog/artifactory-oss:latest
	latest: Pulling from jfrog/artifactory-oss
	25e46ad006a2: Pull complete
	dfbe64cc5477: Pull complete
	aba89f14eeb8: Pull complete
	3e010093287c: Pull complete
	79a89751b512: Pull complete
	2b9076c00287: Pull complete
	66a9c68e4f27: Pull complete
	5cdcc76ff95c: Pull complete
	4e22c7033a7d: Pull complete
	cfac42f52eb8: Pull complete
	f41860f30e65: Pull complete
	2e3c38985ed1: Pull complete
	313c5eda6631: Pull complete
	f350af342675: Pull complete
	8758e36bb71a: Pull complete
	Digest: sha256:32c4d1755df530a3cf96bab35aa15a3e27fc1a1aeeb52e3f10a054b6f2609f60
	Status: Downloaded newer image for docker.bintray.io/jfrog/artifactory-oss:latest
	
	root@kubemaster:~# docker images
	REPOSITORY                                           TAG                 IMAGE ID            CREATED             SIZE
	docker.bintray.io/jfrog/artifactory-oss              latest              c86afaebe1be        2 days ago          805MB
	
3) Create Data Directory (Create data directory on host system to ensure data used on container is persistent)

	root@kubemaster:~# sudo mkdir -p /jfrog/artifactory
	root@kubemaster:~# sudo chown -R 1030 /jfrog/

4) Start JFrog Artifactory container

	root@kubemaster:~# docker run --name artifactory -d -p 8081:8081 \
	>    -v /jfrog/artifactory:/var/opt/jfrog/artifactory \
	>    -e EXTRA_JAVA_OPTIONS='-Xms512m -Xmx2g -Xss256k -XX:+UseG1GC' \
	>    docker.bintray.io/jfrog/artifactory-pro:latest

5) Running JFrog Artifactory container with Systemd
	root@kubemaster:~# sudo vim /etc/systemd/system/artifactory.service
	root@kubemaster:~# sudo systemctl daemon-reload
	root@kubemaster:~# sudo systemctl start artifactory
	root@kubemaster:~# sudo systemctl enable artifactory
	Created symlink /etc/systemd/system/multi-user.target.wants/artifactory.service → /etc/systemd/system/artifactory.service.
	root@kubemaster:~# sudo systemctl status artifactory
	● artifactory.service - Setup Systemd script for Artifactory Container
	   Loaded: loaded (/etc/systemd/system/artifactory.service; enabled; vendor preset: enabled)
	   Active: active (running) since Thu 2019-08-22 13:36:26 UTC; 26s ago
	 Main PID: 25059 (docker)
		Tasks: 10 (limit: 4915)
	   CGroup: /system.slice/artifactory.service
			   └─25059 /usr/bin/docker run --name artifactory -p 8081:8081 -v /jfrog/artifactory:/var/opt/jfrog/artifactory docker.bintray.io/jfrog/artifactory-oss:latest

6) Access Artifactory Web Interface

		http://35.231.201.97:8081/artifactory

```
