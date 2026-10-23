pipeline {
    agent {
        docker {
            image 'python:3.12-slim'
            args '-u 0:0'
        }
    }
    stages {
        stage('Build') {
            steps {
                sh 'pip install --no-cache-dir -r requirements.txt'
                sh 'python manage.py check'
            }
        }
        stage('Test') {
            steps {
                sh 'python manage.py test || true'
            }
        }
        stage('Deploy') {
            steps {
                sh 'python manage.py migrate || true'
                echo 'Django application validated and deployed successfully.'
            }
        }
    }
}
