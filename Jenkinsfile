// Jenkinsfile — Flutter Micro-Module CI/CD pipeline
// Repo: https://github.com/vinaykumarreddy909/ci.git
//
// Cache strategy:
//   • resolve_modules.sh  checks each module's remote Git hash against the
//     cached hash stored in MODULE_CACHE_DIR/<module>/.resolved_hash
//   • Only modules whose hash changed (or that are missing) are re-cloned.
//   • patch_pubspec.sh rewrites path: dependencies to point at the cache.

pipeline {
    agent any

    environment {
        MODULE_CACHE_DIR = '/var/jenkins_home/module_cache'
        PUB_CACHE         = '/var/jenkins_home/.pub-cache'
        FLUTTER_ROOT      = '/flutter'
        PATH              = "${env.FLUTTER_ROOT}/bin:${env.PATH}"
        SHELL_APP_REPO    = 'https://github.com/vinaykumarreddy909/shell_app.git'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        // ----------------------------------------------------------------
        stage('Checkout CI Config') {
        // ----------------------------------------------------------------
            steps {
                checkout scm
            }
        }

        // ----------------------------------------------------------------
        stage('Checkout Shell App') {
        // ----------------------------------------------------------------
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USERNAME',
                    passwordVariable: 'GIT_PASSWORD'
                )]) {
                    sh '''
                        AUTH_URL=$(echo "$SHELL_APP_REPO" | sed "s|https://|https://${GIT_USERNAME}:${GIT_PASSWORD}@|")
                        if [ -d shell_app/.git ]; then
                            git -C shell_app reset --hard HEAD
                            git -C shell_app clean -fd
                            git -C shell_app pull --ff-only "$AUTH_URL" main
                        else
                            git clone --depth=1 "$AUTH_URL" shell_app
                        fi
                    '''
                }
            }
        }

        // ----------------------------------------------------------------
        stage('Resolve & Cache Modules') {
        // ----------------------------------------------------------------
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USERNAME',
                    passwordVariable: 'GIT_PASSWORD'
                )]) {
                    sh '''
                        chmod +x scripts/resolve_modules.sh
                        scripts/resolve_modules.sh
                    '''
                }
            }
            post {
                success {
                    echo 'Module cache is up-to-date.'
                }
            }
        }

        // ----------------------------------------------------------------
        stage('Flutter pub get') {
        // ----------------------------------------------------------------
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USERNAME',
                    passwordVariable: 'GIT_PASSWORD'
                )]) {
                    dir('shell_app') {
                        sh '''
                            # Configure git credential store so Dart pub can clone
                            # the private git: module dependencies via HTTPS.
                            CREDS=$(mktemp)
                            chmod 600 "$CREDS"
                            echo "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com" > "$CREDS"
                            git config --global credential.helper "store --file=${CREDS}"
                            flutter pub get --no-example
                            git config --global --unset credential.helper || true
                            rm -f "$CREDS"
                        '''
                    }
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
                    chmod +x scripts/run_tests.sh
                    WORKSPACE=$(pwd) scripts/run_tests.sh
                '''
            }
        }

        // // ----------------------------------------------------------------
        // stage('Build APK (release)') {
        // // ----------------------------------------------------------------
        //     steps {
        //         dir('shell_app') {
        //             sh '''
        //                 [ -d android ] || { echo "ERROR: android/ not found. Run: flutter create --project-name shell_app --org com.example . inside shell_app and push."; exit 1; }

        //                 # Android SDK cmake 3.22.1 ships only x86_64 Linux binaries.
        //                 # On ARM64 hosts the download fails with "rosetta error".
        //                 # Pre-seed the cmake 3.22.1 SDK path with the ARM64 system
        //                 # cmake/ninja installed via apt so AGP skips the download.
        //                 CMAKE_SDK_DIR="${ANDROID_HOME}/cmake/3.22.1"
        //                 if [ ! -x "${CMAKE_SDK_DIR}/bin/cmake" ]; then
        //                     mkdir -p "${CMAKE_SDK_DIR}/bin"
        //                     cp "$(which cmake)"  "${CMAKE_SDK_DIR}/bin/cmake"
        //                     cp "$(which ninja)"  "${CMAKE_SDK_DIR}/bin/ninja"
        //                     echo "cmake $(cmake --version | head -1)" > "${CMAKE_SDK_DIR}/package.xml" || true
        //                 fi

        //                 flutter build apk --release --no-pub
        //             '''
        //         }
        //         archiveArtifacts artifacts: 'shell_app/build/app/outputs/flutter-apk/*.apk', fingerprint: true
        //     }
        // }

        // ----------------------------------------------------------------
        stage('Build Web') {
        // ----------------------------------------------------------------
            steps {
                dir('shell_app') {
                    sh '''
                        [ -d web ] || { echo "ERROR: web/ not found. Run: flutter create --project-name shell_app --org com.example . inside shell_app and push."; exit 1; }
                        flutter build web --release --no-pub
                    '''
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
