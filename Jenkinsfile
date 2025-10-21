pipeline {
  agent any

  environment {
    DOCKER_IMAGE = "eknathdj/devops-sample-app"
    DOCKER_CREDENTIALS_ID = "dockerhub-creds"   // Jenkins: Username with password (Docker Hub user + token)
    GITHUB_CREDENTIALS_ID = "github-creds"      // Jenkins: Username with password (GitHub user + PAT)
    IMAGE_TAG = "${BUILD_NUMBER}"
    GITHUB_REPO = "https://github.com/eknathdj/devops-argocd-jenkins-app.git"
  }

  stages {
    stage('Cleanup Workspace') {
      steps { cleanWs() }
    }

    stage('Checkout Code') {
      steps {
        git branch: 'main',
            credentialsId: "${GITHUB_CREDENTIALS_ID}",
            url: "${GITHUB_REPO}"
      }
    }

    stage('Build Docker Image') {
      steps {
        echo "Building Docker image ${DOCKER_IMAGE}:${IMAGE_TAG} ..."
        script {
          // Build image using Docker Pipeline plugin
          def builtImage = docker.build("${DOCKER_IMAGE}:${IMAGE_TAG}")
          // Tag as latest (creates local tag)
          builtImage.tag("latest")
        }
      }
    }

    stage('Push to DockerHub') {
      steps {
        echo "Pushing ${DOCKER_IMAGE}:${IMAGE_TAG} and latest to Docker Hub..."
        script {
          // Get image handle for the built image
          def img = docker.image("${DOCKER_IMAGE}:${IMAGE_TAG}")
          // Use docker.withRegistry and pass the credentials id (type: username/password)
          docker.withRegistry("https://registry.hub.docker.com", "${DOCKER_CREDENTIALS_ID}") {
            // push the specific tag and latest
            img.push("${IMAGE_TAG}")
            img.push("latest")
          }
        }
      }
    }

    stage('Update Kubernetes Manifest') {
      steps {
        script {
          // Use usernamePassword so Jenkins expects Username with password credential type
          withCredentials([usernamePassword(credentialsId: "${GITHUB_CREDENTIALS_ID}",
                                            usernameVariable: 'GIT_USER',
                                            passwordVariable: 'GITHUB_TOKEN')]) {
            sh '''
              set -e
              git config user.email "jenkins@ci.com"
              git config user.name "Jenkins CI"

              # Update the manifest with the new image tag
              sed -i 's|image: ${DOCKER_IMAGE}:.*|image: ${DOCKER_IMAGE}:${IMAGE_TAG}|g' environments/staging/deployment.yaml

              git add environments/staging/deployment.yaml
              git commit -m "Update staging image to ${IMAGE_TAG}" || echo "No changes to commit"

              # Use explicit remote URL with credentials (credentials will be masked)
              # If you prefer token-only auth, use x-access-token as username:
              # git remote set-url origin https://x-access-token:${GITHUB_TOKEN}@github.com/eknathdj/devops-argocd-jenkins-app.git
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
      // best-effort logout
      sh 'docker logout || true'
    }
    success { echo 'Pipeline completed successfully!' }
    failure { echo 'Pipeline failed!' }
  }
}
