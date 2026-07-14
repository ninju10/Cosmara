pipeline {
    agent any

    environment {
        IMAGE_NAME = 'cosmara'
        IMAGE_TAG = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'cosmara-app'
        APP_PORT = '8496'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    stages {

        stage('Checkout') {
            steps {
                echo '========== Checking out code =========='
                checkout scm
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    echo "Checking required files..."

                    test -f Dockerfile
                    test -f index.html
                    test -f styles.css

                    echo "All required files found"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "Building Docker image..."

                    docker build \
                      -t ${IMAGE_NAME}:${IMAGE_TAG} \
                      -t ${IMAGE_NAME}:latest \
                      .

                    echo "Docker image built successfully"
                '''
            }
        }

        stage('Test Docker Image') {
            steps {
                sh '''
                    echo "Testing Docker image..."

                    TEST_CONTAINER=test-cosmara

                    docker rm -f $TEST_CONTAINER 2>/dev/null || true

                    docker run -d \
                      --name $TEST_CONTAINER \
                      -p 7262:80 \
                      ${IMAGE_NAME}:${IMAGE_TAG}

                    sleep 5

                    curl -f http://localhost:7262/

                    docker rm -f $TEST_CONTAINER

                    echo "Docker image test passed"
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    echo "Deploying application..."

                    docker stop ${CONTAINER_NAME} || true
                    docker rm ${CONTAINER_NAME} || true

                    docker run -d \
                      --name ${CONTAINER_NAME} \
                      -p ${APP_PORT}:80 \
                      --restart unless-stopped \
                      ${IMAGE_NAME}:${IMAGE_TAG}

                    sleep 5

                    curl -f http://localhost:${APP_PORT}/

                    echo "Deployment successful"
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }

        failure {
            echo 'Pipeline failed!'
        }

        always {
            sh '''
                docker container prune -f || true
            '''
        }
    }
}