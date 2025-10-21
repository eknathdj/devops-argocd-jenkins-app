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
        
        stage('Commit and Push Manifest Changes') {
            steps {
                echo 'Committing manifest changes...'
                script {
                    withCredentials([usernamePassword(credentialsId: GITHUB_CREDENTIALS, 
                                                      usernameVariable: 'GIT_USERNAME', 
                                                      passwordVariable: 'GIT_PASSWORD')]) {
                        sh """
                            # Configure Git
                            git config user.email "jenkins@example.com"
                            git config user.name "Jenkins CI"
                            
                            # Checkout main branch (fix detached HEAD)
                            git checkout main
                            git pull origin main
                            
                            # Add the modified file
                            git add environments/staging/deployment.yaml
                            
                            # Only commit and push if there are changes
                            if git diff --staged --quiet; then
                                echo "No changes to commit"
                            else
                                git commit -m "Update image to ${DOCKER_IMAGE}:${DOCKER_TAG}"
                                git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/eknathdj/devops-sample-app.git main
                            fi
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