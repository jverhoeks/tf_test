pipeline {
  agent any
  stages {
    stage('Plan') {
      parallel {
        stage('stg') {
          steps {
            sh 'ls'
          }
        }
        stage('prd') {
          steps {
            echo 'test'
          }
        }
      }
    }
    stage('Select') {
      steps {
        input(message: 'test', id: 'test')
      }
    }
    stage('Apply') {
      parallel {
        stage('stg') {
          steps {
            echo 'apply stg'
          }
        }
        stage('prd') {
          steps {
            echo 'apply prd'
          }
        }
      }
    }
    stage('Cleanup') {
      steps {
        cleanWs(cleanWhenAborted: true, cleanWhenFailure: true, cleanWhenSuccess: true)
      }
    }
  }
}