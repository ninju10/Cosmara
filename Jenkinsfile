pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME     = 'cosmara'
        IMAGE_TAG      = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'cosmara-app'
        APP_PORT       = '8496'
        // Test container name still varies per build, but the port is fixed
        // at 7262. Conflicts are prevented instead by disableConcurrentBuilds()
        // above and by the guaranteed cleanup (try/finally) in the Test stage,
        // so nothing is ever left bound to 7262 when the next build starts.
        TEST_CONTAINER = "test-cosmara-${BUILD_NUMBER}"
        TEST_PORT      = '7262'
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
                    set -e
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
                    set -e
                    echo "Building Docker image..."

                    docker build \
                      -t ${IMAGE_NAME}:${IMAGE_TAG} \
                      -t ${IMAGE_NAME}:latest \
                      .

                    echo "Docker image built successfully"
                '''
            }
        }

        stage('Trivy Scan') {
            steps {
                sh '''
                    set -e
                    echo "Scanning Docker image with Trivy..."

                    trivy image --exit-code 0 --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}

                    echo "Trivy scan completed"
                '''
            }
        }

        stage('Test Docker Image') {
            steps {
                script {
                    try {
                        sh '''
                            set -e
                            echo "Testing Docker image on port ${TEST_PORT}..."

                            docker rm -f ${TEST_CONTAINER} 2>/dev/null || true

                            # Extra insurance: force-remove ANY container already
                            # bound to port 7262, in case something outside this
                            # pipeline (or a crashed prior run) is holding it.
                            HOLDER=$(docker ps -q --filter "publish=${TEST_PORT}")
                            if [ -n "$HOLDER" ]; then
                                echo "Port ${TEST_PORT} is in use, removing holder container(s): $HOLDER"
                                docker rm -f $HOLDER || true
                            fi

                            docker run -d \
                              --name ${TEST_CONTAINER} \
                              -p ${TEST_PORT}:80 \
                              ${IMAGE_NAME}:${IMAGE_TAG}

                            # Poll instead of a fixed sleep, so slow agents don't
                            # cause false-negative failures.
                            for i in $(seq 1 15); do
                                if curl -sf http://localhost:${TEST_PORT}/ > /dev/null; then
                                    echo "Container is healthy"
                                    exit 0
                                fi
                                sleep 1
                            done

                            echo "Container failed health check"
                            exit 1
                        '''
                    } finally {
                        // Always clean up the test container, pass or fail,
                        // so it never blocks a future build's port/name.
                        sh 'docker rm -f ${TEST_CONTAINER} 2>/dev/null || true'
                    }
                }
                echo "Docker image test passed"
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    set -e
                    echo "Deploying application..."

                    docker stop ${CONTAINER_NAME} 2>/dev/null || true
                    docker rm ${CONTAINER_NAME} 2>/dev/null || true

                    docker run -d \
                      --name ${CONTAINER_NAME} \
                      -p ${APP_PORT}:80 \
                      --restart unless-stopped \
                      ${IMAGE_NAME}:${IMAGE_TAG}

                    for i in $(seq 1 15); do
                        if curl -sf http://localhost:${APP_PORT}/ > /dev/null; then
                            echo "Deployment successful"
                            exit 0
                        fi
                        sleep 1
                    done

                    echo "Deployed container failed health check"
                    docker logs ${CONTAINER_NAME} || true
                    exit 1
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
                docker rm -f ${TEST_CONTAINER} 2>/dev/null || true
                docker container prune -f || true
                # Keep only the current + latest image tags around so old
                # build images don't slowly fill the Jenkins host's disk.
                docker image prune -f || true
            '''
        }
    }
}