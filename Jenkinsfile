pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "eknathdj/devops-sample-app"
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        GITHUB_CREDENTIALS = credentials('github-creds')
        IMAGE_TAG = "${BUILD_NUMBER}"
        GITHUB_REPO = "https://github.com/eknathdj/devops-argocd-jenkins-app.git"
    }
    
    stages {
        stage('Cleanup Workspace') {
            steps {
                cleanWs()
            }
        }
        
        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: "${GITHUB_REPO}"
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                        docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }
        
        stage('Login to DockerHub') {
            steps {
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
            }
        }
        
        stage('Push Docker Image') {
            steps {
                sh """
                    docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                    docker push ${DOCKER_IMAGE}:latest
                """
            }
        }
        
        stage('Update Kubernetes Manifest') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'github-creds', variable: 'GITHUB_TOKEN')]) {
                        sh """
                            git config user.email "jenkins@ci.com"
                            git config user.name "Jenkins CI"
                            
                            # Update staging deployment
                            sed -i 's|image: ${DOCKER_IMAGE}:.*|image: ${DOCKER_IMAGE}:${IMAGE_TAG}|g' environments/staging/deployment.yaml
                            
                            git add environments/staging/deployment.yaml
                            git commit -m "Update staging image to ${IMAGE_TAG}" || echo "No changes to commit"
                            git push https://${GITHUB_TOKEN}@github.com/eknathdj/devops-argocd-jenkins-app.git main
                        """
                    }
                }
            }
        }
        
        stage('Cleanup Docker Images') {
            steps {
                sh """
                    docker rmi ${DOCKER_IMAGE}:${IMAGE_TAG} || true
                    docker rmi ${DOCKER_IMAGE}:latest || true
                """
            }
        }
    }
    
    post {
        always {
            sh 'docker logout'
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}