pipeline {
    agent any

    environment {
        // Docker registry credentials (configure these in Jenkins)
        DOCKER_REGISTRY = 'docker.io'  // Change to your registry
        DOCKER_REPO = 'your-username/cosmara'  // Change to your repo
        IMAGE_TAG = "${BUILD_NUMBER}"
        // NOTE: DOCKER_CREDENTIALS is intentionally NOT bound here.
        // Binding credentials() at the top-level `environment` block runs
        // immediately after checkout, before any stage executes. If the
        // 'docker-credentials' ID doesn't exist yet in Jenkins, the whole
        // pipeline fails right away with no stages shown. Instead, the
        // credential is only requested inside the "Push to Registry" stage
        // via withCredentials(), so Build/Test/Scan still run fine even if
        // you haven't configured Docker Hub credentials yet.
    }

    options {
        // Keep last 10 builds
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // Timeout after 30 minutes
        timeout(time: 30, unit: 'MINUTES')
        // Add timestamps to console output
        timestamps()
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo '========== Checking out code =========='
                    checkout scm
                }
            }
        }

        stage('Validate') {
            steps {
                script {
                    echo '========== Validating files =========='
                    sh '''
                        echo "Checking if Dockerfile exists..."
                        test -f Dockerfile || exit 1
                        echo "Checking if index.html exists..."
                        test -f index.html || exit 1
                        echo "Checking if styles.css exists..."
                        test -f styles.css || exit 1
                        echo "All required files found"
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo '========== Building Docker image =========='
                    sh '''
                        docker build \
                            --tag ${DOCKER_REPO}:${IMAGE_TAG} \
                            --tag ${DOCKER_REPO}:latest \
                            --label "build.number=${BUILD_NUMBER}" \
                            --label "build.timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
                            .
                        echo "Docker image built successfully"
                    '''
                }
            }
        }

        stage('Test Docker Image') {
            steps {
                script {
                    echo '========== Testing Docker image =========='
                    sh '''
                        # Run container in background
                        CONTAINER_ID=$(docker run -d -p 7262:80 ${DOCKER_REPO}:${IMAGE_TAG})
                        sleep 3

                        # Test if nginx is responding
                        echo "Testing nginx response..."
                        curl -f http://localhost:7262/ > /dev/null || { docker logs $CONTAINER_ID; docker rm -f $CONTAINER_ID; exit 1; }

                        # Check if HTML file is served
                        echo "Verifying index.html is served..."
                        curl -s http://localhost:7262/ | grep -q "COSMARA" || { docker rm -f $CONTAINER_ID; exit 1; }

                        # Cleanup
                        docker stop $CONTAINER_ID
                        docker rm $CONTAINER_ID

                        echo "Docker image tests passed"
                    '''
                }
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    echo '========== Running security scan =========='
                    sh '''
                        echo "Scanning Dockerfile for security issues..."
                        # Check for security best practices
                        ! grep -q "USER root" Dockerfile || echo "Warning: Container may run as root"
                        echo "Basic security checks completed"
                    '''
                }
            }
        }

        stage('Push to Registry') {
            when {
                anyOf {
                    branch 'main'                                    // works in Multibranch Pipeline jobs
                    expression { env.GIT_BRANCH == 'origin/main' }    // works in plain Pipeline jobs
                    expression { env.GIT_BRANCH == 'main' }
                }
            }
            steps {
                script {
                    echo '========== Pushing image to registry =========='
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh '''
                            echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin ${DOCKER_REGISTRY}
                            docker push ${DOCKER_REPO}:${IMAGE_TAG}
                            docker push ${DOCKER_REPO}:latest
                            docker logout ${DOCKER_REGISTRY}
                            echo "Image pushed successfully"
                        '''
                    }
                }
            }
        }

        stage('Deploy') {
            when {
                anyOf {
                    branch 'main'
                    expression { env.GIT_BRANCH == 'origin/main' }
                    expression { env.GIT_BRANCH == 'main' }
                }
            }
            steps {
                script {
                    echo '========== Deploying container =========='
                    sh '''
                        # Stop and remove existing container (if running)
                        docker stop cosmara-app || true
                        docker rm cosmara-app || true

                        # Run new container
                        docker run -d \
                            --name cosmara-app \
                            -p 80:80 \
                            --restart unless-stopped \
                            ${DOCKER_REPO}:${IMAGE_TAG}

                        sleep 2

                        # Verify deployment
                        curl -f http://localhost/ > /dev/null || exit 1
                        echo "Application deployed successfully"
                        docker ps | grep cosmara-app
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                echo '========== Cleanup =========='
                // Clean up test containers if they exist
                sh 'docker container prune -f --filter "until=24h" || true'
            }
        }
        success {
            echo 'Pipeline executed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
            // Add notification here (email, Slack, etc.)
        }
    }
}