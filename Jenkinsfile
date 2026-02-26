pipeline {
agent any

```
tools {
    nodejs "node23"
}

environment {
    AWS_REGION   = "ap-south-2"
    CLUSTER_NAME = "tyson-cluster"
    DOCKER_IMAGE = "prakash1362/nodejsapp-9.0:latest"
    PATH = "${env.WORKSPACE}/bin:${env.PATH}"
}

stages {

    stage('Prepare Tools (kubectl & eksctl)') {
        steps {
            sh '''
                set -e
                mkdir -p ${WORKSPACE}/bin

                # Install kubectl (only if missing)
                if [ ! -f ${WORKSPACE}/bin/kubectl ]; then
                  curl -sLO https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl
                  chmod +x kubectl
                  mv kubectl ${WORKSPACE}/bin/
                fi

                # Install eksctl (only if missing)
                if [ ! -f ${WORKSPACE}/bin/eksctl ]; then
                  curl -sLO https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz
                  tar -xzf eksctl_Linux_amd64.tar.gz
                  mv eksctl ${WORKSPACE}/bin/
                fi

                kubectl version --client
                eksctl version
            '''
        }
    }

    stage('Clone Code') {
        steps {
            checkout scm
        }
    }

    stage('NodeJS Build') {
        steps {
            sh 'npm install'
        }
    }

    stage('Build & Push Docker Image') {
        steps {
            withCredentials([usernamePassword(
                credentialsId: 'docker-creds',
                usernameVariable: 'DOCKER_USER',
                passwordVariable: 'DOCKER_PASS'
            )]) {
                sh '''
                    set -e
                    echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                    docker build -t $DOCKER_IMAGE .
                    docker push $DOCKER_IMAGE
                '''
            }
        }
    }

    stage('Create/Check EKS Cluster') {
        steps {
            script {
                echo "Checking EKS cluster..."

                def exists = sh(
                    script: "eksctl get cluster --name ${CLUSTER_NAME} --region ${AWS_REGION}",
                    returnStatus: true
                ) == 0

                if (!exists) {
                    echo "Creating EKS cluster..."
                    sh """
                        eksctl create cluster \
                          --name ${CLUSTER_NAME} \
                          --region ${AWS_REGION} \
                          --nodegroup-name worker-nodes \
                          --node-type t3.medium \
                          --nodes 2 \
                          --managed
                    """
                } else {
                    echo "Cluster already exists."
                }

                sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}"
            }
        }
    }

    stage('Deploy App to EKS') {
        steps {
            sh '''
                set -e

                echo "Deploying application..."
                kubectl apply -f nodejsapp.yaml

                echo "Waiting for deployment rollout..."
                kubectl rollout status deployment/nodejs-app --timeout=300s

                echo "Waiting for LoadBalancer..."
                SUCCESS=false

                for i in {1..40}; do
                  HOST=$(kubectl get svc nodejs-app -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null || true)

                  if [ ! -z "$HOST" ]; then
                    echo "================================="
                    echo "APP URL: http://$HOST"
                    echo "================================="
                    SUCCESS=true
                    break
                  fi

                  echo "Waiting for external IP... ($i/40)"
                  sleep 15
                done

                if [ "$SUCCESS" = false ]; then
                  echo "ERROR: LoadBalancer not ready in time"
                  kubectl get svc
                  exit 1
                fi
            '''
        }
    }
}

post {
    always {
        echo 'Pipeline execution finished ✅'
    }
}
}
