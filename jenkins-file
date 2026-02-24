pipeline {
    agent any

    tools {
        nodejs "node23"
    }

    environment {
        AWS_REGION   = "ap-south-2"
        CLUSTER_NAME = "tyson-cluster"
        DOCKER_IMAGE = "prakash/nodejsapp-9.0:latest"
        PATH = "${env.WORKSPACE}/bin:${env.PATH}"
    }

    stages {

        stage('Prepare Tools (kubectl & eksctl)') {
            steps {
                script {
                    echo "Installing kubectl and eksctl..."
                    sh '''
                        mkdir -p ${WORKSPACE}/bin

                        # Install kubectl
                        curl -LO https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl
                        chmod +x kubectl
                        mv kubectl ${WORKSPACE}/bin/

                        # Install eksctl
                        curl -sLO https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz
                        tar -xzf eksctl_Linux_amd64.tar.gz
                        mv eksctl ${WORKSPACE}/bin/

                        kubectl version --client
                        eksctl version
                    '''
                }
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
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh '''
                            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                            docker build -t $DOCKER_IMAGE .
                            docker push $DOCKER_IMAGE
                        '''
                    }
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
                script {
                    sh '''
                        kubectl apply -f nodejsapp.yaml

                        echo "Waiting for LoadBalancer..."

                        for i in {1..30}; do
                          HOST=$(kubectl get svc nodejs-service -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null || true)
                          if [ ! -z "$HOST" ]; then
                            echo "================================="
                            echo "APP URL: http://$HOST"
                            echo "================================="
                            break
                          fi
                          echo "Waiting for external IP... ($i/30)"
                          sleep 20
                        done
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline execution finished ✅'
        }
    }
}
