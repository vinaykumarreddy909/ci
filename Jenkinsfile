// Jenkinsfile — Flutter Micro-Module CI/CD pipeline
// Cache strategy:
//   • resolve_modules.sh  checks each module's remote Git hash against the
//     cached hash stored in MODULE_CACHE_DIR/<module>/.resolved_hash
//   • Only modules whose hash changed (or that are missing) are re-cloned.
//   • patch_pubspec.sh rewrites path: dependencies to point at the cache.
//
// CI_DIR: set to 'ci' when this Jenkinsfile lives inside a subdirectory of the
// main project. Set to '' (empty) when this repo is used as a standalone CI repo.

pipeline {
    agent any

    environment {
        MODULE_CACHE_DIR = '/var/jenkins_home/module_cache'
        PUB_CACHE         = '/root/.pub-cache'
        FLUTTER_ROOT      = '/flutter'
        PATH              = "${env.FLUTTER_ROOT}/bin:${env.PATH}"
        CI_DIR            = 'ci'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        // ----------------------------------------------------------------
        stage('Checkout') {
        // ----------------------------------------------------------------
            steps {
                checkout scm
            }
        }

        // ----------------------------------------------------------------
        stage('Resolve & Cache Modules') {
        // ----------------------------------------------------------------
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        sh '''
                            chmod +x ${CI_DIR}/scripts/resolve_modules.sh
                            MODULE_REGISTRY="${WORKSPACE}/${CI_DIR}/module_registry.yaml" \
                                ${CI_DIR}/scripts/resolve_modules.sh
                        '''
                    }
                }
            }
            post {
                success {
                    echo 'Module cache is up-to-date.'
                }
            }
        }

        // ----------------------------------------------------------------
        stage('Patch pubspec.yaml') {
        // ----------------------------------------------------------------
            steps {
                sh '''
                    chmod +x ${CI_DIR}/scripts/patch_pubspec.sh
                    WORKSPACE=$(pwd) ${CI_DIR}/scripts/patch_pubspec.sh
                '''
            }
        }

        // ----------------------------------------------------------------
        stage('Flutter pub get') {
        // ----------------------------------------------------------------
            steps {
                dir('shell_app') {
                    sh 'flutter pub get --no-example'
                }
            }
        }

        // ----------------------------------------------------------------
        stage('Analyze') {
        // ----------------------------------------------------------------
            steps {
                dir('shell_app') {
                    sh 'flutter analyze --no-pub'
                }
            }
        }

        // ----------------------------------------------------------------
        stage('Test') {
        // ----------------------------------------------------------------
            steps {
                sh '''
                    chmod +x ${CI_DIR}/scripts/run_tests.sh
                    WORKSPACE=$(pwd) ${CI_DIR}/scripts/run_tests.sh
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/test-results/**/*.xml'
                }
            }
        }

        // ----------------------------------------------------------------
        stage('Build APK (release)') {
        // ----------------------------------------------------------------
            steps {
                dir('shell_app') {
                    sh 'flutter build apk --release --no-pub'
                }
                archiveArtifacts artifacts: 'shell_app/build/app/outputs/flutter-apk/*.apk', fingerprint: true
            }
        }

        // ----------------------------------------------------------------
        stage('Build Web') {
        // ----------------------------------------------------------------
            steps {
                dir('shell_app') {
                    sh 'flutter build web --release --no-pub'
                }
                archiveArtifacts artifacts: 'shell_app/build/web/**', fingerprint: true
            }
        }

        // ----------------------------------------------------------------
        stage('Deploy Local') {
        // ----------------------------------------------------------------
            steps {
                sh '''
                    rm -rf /var/web_serve/*
                    cp -r shell_app/build/web/. /var/web_serve/
                '''
                echo 'Web app deployed — open http://localhost:8090 to view it.'
            }
        }
    }

    post {
        failure {
            echo 'Pipeline failed. Check logs above for details.'
        }
        success {
            echo 'Pipeline completed successfully.'
        }
    }
}
