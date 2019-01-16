pipeline {
  agent any
  stages {
    stage('Plan') {
      parallel {
        stage('Staging') {
          environment {
            ENV = 'staging'
          }
          steps {
            withCredentials(bindings: [[
                                               $class: 'AmazonWebServicesCredentialsBinding',
                                               credentialsId: 'jenkins-terraform-staging-role'
                                           ]]) {
                sh '[ ! -d ".terraform" ] && make init'
                sh 'make'
              }

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
              slackSend(channel: '#jenkins', message: "Terraform _Staging_ Requires *Approval*:   (<${env.RUN_DISPLAY_URL}|${env.JOB_NAME}>)")
              timeout(time: 30, unit: 'MINUTES') {
                input 'Run Apply on staging'
              }

              withCredentials(bindings: [[
                                                   $class: 'AmazonWebServicesCredentialsBinding',
                                                   credentialsId: 'jenkins-terraform-staging-role'
                                               ]]) {
                  sh 'make auto-apply'
                }

                slackSend(channel: '#jenkins', message: "Terraform _Staging_ Applied (<${env.RUN_DISPLAY_URL}|${env.JOB_NAME}>)")
              }
            }
            stage('Apply Production') {
              when {
                branch 'master'
              }
              steps {
                slackSend(channel: '#jenkins', message: "Terraform _Production Requires *Approval*:   (<${env.RUN_DISPLAY_URL}|${env.JOB_NAME}>)")
                timeout(time: 30, unit: 'MINUTES') {
                  input 'Run Apply on production'
                }

                echo 'apply production'
                slackSend(channel: '#jenkins', message: "Terraform _Production_ Applied   (<${env.RUN_DISPLAY_URL}|${env.JOB_NAME}>)")
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