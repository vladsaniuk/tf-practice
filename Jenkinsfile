pipeline {
    agent any
    parameters {
      string(name: "ENV", defaultValue: "dev", description: "Env name")
      string(name: "ACTION", defaultValue: "plan", description: "tf action: plan/apply/destroy")
      string(name: "TARGET", defaultValue: "", description: "tf target")
    }
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        if BRANCH_NAME == 'master' && params.ENV == 'prod' {
            buildDiscarder(logRotator(artifactDaysToKeepStr: '30', artifactNumToKeepStr: '10', daysToKeepStr: '30', numToKeepStr: '30'))
        } else {
            buildDiscarder(logRotator(artifactDaysToKeepStr: '5', artifactNumToKeepStr: '2', daysToKeepStr: '5', numToKeepStr: '10'))
        }
    }
    environment {
        AWS_ACCESS_KEY_ID = credentials('aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('aws_secret_access_key')
    }
    stages {
        stage('Init') {
            sh "terraform init -backend-config=backend-${params.ENV}.hcl"
        }
        stage('Plan') {
            if ${params.TARGET} != "" {
                sh """
                terraform plan -var-file ${params.ENV}.tfvars -var="env=${params.ENV}" -var="cluster_name=${params.ENV}-eks-cluster" -target="${params.TARGET}" -out=${params.ENV}_backend.tfplan
                """
            } else {
                sh """
                terraform plan -var-file ${params.ENV}.tfvars -var="env=${params.ENV}" -var="cluster_name=${params.ENV}-eks-cluster" -out=${params.ENV}_backend.tfplan
                """
            }
        }
    }
}