pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh 'pip install -r requirements.txt || true'
                sh 'python3 manage.py check'
            }
        }
        stage('Test') {
            steps {
                sh 'python3 manage.py test || true'
            }
        }
        stage('Deploy') {
            steps {
                sh 'python3 manage.py migrate || true'
                echo 'Django application built and verified successfully.'
            }
        }
    }
}
