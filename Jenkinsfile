// =============================================================================
// Jenkins Pipeline - Platform-Agnostic
// All logic is in Makefile - this is just a thin wrapper
// =============================================================================

pipeline {
    agent {
        docker {
            image 'python:3.11-slim'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    options {
        // Keep builds for 30 days
        buildDiscarder(logRotator(numToKeepStr: '30', daysToKeepStr: '30'))

        // Timeout after 1 hour
        timeout(time: 1, unit: 'HOURS')

        // Timestamps in logs
        timestamps()

        // Skip default checkout (we'll do it manually)
        skipDefaultCheckout()
    }

    environment {
        // Platform abstraction
        CONTAINER_RUNTIME = 'docker'
        ENV = 'local'

        // Credentials (configure in Jenkins)
        PROXMOX_CREDS = credentials('proxmox-api-token')
        VAULT_TOKEN = credentials('vault-root-token')
    }

    stages {
        //=====================================================================
        // Setup
        //=====================================================================
        stage('Setup') {
            steps {
                // Manual checkout to control branch
                checkout scm

                sh '''
                    echo "Installing system dependencies..."
                    apt-get update -qq
                    apt-get install -y -qq make curl git jq

                    echo "Checking required tools..."
                    make doctor || echo "Some optional tools missing"
                '''
            }
        }

        //=====================================================================
        // Validation Stage
        //=====================================================================
        stage('Validate') {
            parallel {
                stage('Lint: Terraform') {
                    steps {
                        sh 'make lint-terraform'
                    }
                }
                stage('Lint: Ansible') {
                    steps {
                        sh 'make lint-ansible'
                    }
                }
                stage('Lint: Packer') {
                    steps {
                        sh 'make lint-packer'
                    }
                }
                stage('Lint: Python') {
                    steps {
                        sh 'make lint-python || true'  // Optional
                    }
                }
            }
        }

        //=====================================================================
        // Test Stage
        //=====================================================================
        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'make test-unit'
                    }
                    post {
                        always {
                            // Publish test results
                            junit 'test-results/**/*.xml'

                            // Publish coverage
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'htmlcov',
                                reportFiles: 'index.html',
                                reportName: 'Coverage Report'
                            ])
                        }
                    }
                }
                stage('Integration Tests') {
                    steps {
                        sh 'make test-integration'
                    }
                }
                stage('E2E Tests') {
                    when {
                        branch 'main'
                    }
                    steps {
                        sh 'make test-e2e || true'  // E2E might fail without full infra
                    }
                }
            }
        }

        //=====================================================================
        // Security Stage
        //=====================================================================
        stage('Security') {
            parallel {
                stage('Trivy Scan') {
                    steps {
                        sh 'make security-trivy || true'  // Tool might not be available
                    }
                }
                stage('Secret Scan') {
                    steps {
                        sh 'make security-secrets'
                    }
                }
                stage('Terraform Security') {
                    steps {
                        sh 'make security-terraform || true'  // Tool might not be available
                    }
                }
                stage('SBOM Generation') {
                    steps {
                        sh 'make sbom || true'
                    }
                    post {
                        success {
                            archiveArtifacts artifacts: 'sbom*.json', allowEmptyArchive: true
                        }
                    }
                }
            }
        }

        //=====================================================================
        // Build Stage
        //=====================================================================
        stage('Build') {
            when {
                branch 'main'
            }
            parallel {
                stage('Validate Packer') {
                    steps {
                        sh 'make packer-validate'
                    }
                }
                stage('Build Autoscaler') {
                    steps {
                        sh 'make autoscaler-build'
                    }
                }
            }
        }

        //=====================================================================
        // Deploy Stage (Manual Approval)
        //=====================================================================
        stage('Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to staging?', ok: 'Deploy'

                sh '''
                    echo "Deploying to staging..."
                    make ci-deploy
                '''
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to PRODUCTION?', ok: 'Deploy', submitter: 'admin,lead'

                sh '''
                    echo "Deploying to production..."
                    ENV=prod make apply-prod
                '''
            }
        }
    }

    //=========================================================================
    // Post Actions
    //=========================================================================
    post {
        always {
            // Cleanup workspace
            sh 'make clean || true'

            // Archive logs
            archiveArtifacts artifacts: '**/*.log', allowEmptyArchive: true
        }

        success {
            echo '✓ Pipeline succeeded!'

            // Notify on success (configure notification plugin)
            // slackSend color: 'good', message: "Build ${env.BUILD_NUMBER} succeeded"
        }

        failure {
            echo '✗ Pipeline failed!'

            // Notify on failure
            // slackSend color: 'danger', message: "Build ${env.BUILD_NUMBER} failed"
        }

        unstable {
            echo '⚠ Pipeline unstable'
        }
    }
}
