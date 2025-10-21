pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "eknathdj/devops-sample-app"
        DOCKER_CREDENTIALS_ID = "dockerhub-creds"
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
                echo 'Building Docker image...'
                script {
                    dockerImage = docker.build("${DOCKER_IMAGE}:${IMAGE_TAG}")
                    // Also tag as latest
                    dockerImage.tag("latest")
                }
            }
        }
        
        // stage('Test') {
        //     steps {
        //         echo 'Running tests...'
        //         script {
        //             docker.image("${DOCKER_IMAGE}:${IMAGE_TAG}").inside {
        //                 sh 'npm test'
        //             }
        //             echo 'Tests passed successfully'
        //         }
        //     }
        // }
        
        stage('Push to DockerHub') {
            steps {
                echo 'Pushing Docker image to DockerHub...'
                script {
                    docker.withRegistry('https://registry.hub.docker.com', DOCKER_CREDENTIALS_ID) {
                        dockerImage.push("${IMAGE_TAG}")
                        dockerImage.push("latest")
                    }
                }
            }
        }
        
        // stage('Push Docker Image') {
        //     steps {
        //         sh """
        //             docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
        //             docker push ${DOCKER_IMAGE}:latest
        //         """
        //     }
        // }
        
        stage('Update Kubernetes Manifest') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'github-creds',
                                                    usernameVariable: 'GIT_USER',
                                                    passwordVariable: 'GITHUB_TOKEN')]) {
                    sh '''
                        git config user.email "jenkins@ci.com"
                        git config user.name "Jenkins CI"
                        sed -i 's|image: ${DOCKER_IMAGE}:.*|image: ${DOCKER_IMAGE}:${IMAGE_TAG}|g' environments/staging/deployment.yaml
                        git add environments/staging/deployment.yaml
                        git commit -m "Update staging image to ${IMAGE_TAG}" || echo "No changes to commit"
                        # Set origin to include credentials (masked in logs)
                        git remote set-url origin https://${GIT_USER}:${GITHUB_TOKEN}@github.com/eknathdj/devops-argocd-jenkins-app.git
                        git push origin main
                    '''
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