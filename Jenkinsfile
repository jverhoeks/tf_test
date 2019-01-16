pipeline {
  agent any
  stages {
    stage('Plan') {
      parallel {
        stage('Staging') {
          environment {
            ENV = 'staging'
            role = 'jenkins-terraform-staging-role'
          }
          steps {
            echo 'test'
          }
        }
        stage('Production') {
          environment {
            ENV = 'production'
          }
          steps {
            echo 'planning production'
          }
        }
      }
    }
    stage('Apply') {
      parallel {
        stage('apply Staging') {
          when {
            branch 'master'
          }
          steps {
            timeout(time: 30, unit: 'MINUTES') {
              input 'Run Apply on staging'
            }

            withCredentials(bindings: [[
                                                 $class: 'AmazonWebServicesCredentialsBinding',
                                                 credentialsId: 'jenkins-terraform-staging-role'
                                             ]]) {
                sh 'make auto-apply'
              }

            }
          }
          stage('Apply Production') {
            when {
              branch 'master'
            }
            steps {
              timeout(time: 30, unit: 'MINUTES') {
                input 'Run Apply on production'
              }

              echo 'apply production'
            }
          }
        }
      }
    }
    environment {
      AWS_DEFAULT_REGION = 'eu-west-1'
    }
    post {
      always {
        cleanWs()

      }

    }
  }