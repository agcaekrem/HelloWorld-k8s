node{
    
    stage("Git Clone"){

        git credentialsId: 'GIT_HUB_CREDENTIALS', url: 'https://github.com/agcaekrem/HelloWorld-k8s.git'
    }
    
    stage(" Maven Clean Package"){
      def mavenHome =  tool name: "Maven-3.8.6", type: "maven"
      def mavenCMD = "${mavenHome}/bin/mvn"
      sh "${mavenCMD} clean package"
       } 
     
      stage('Build Docker Image'){
       sh 'docker version'
       sh 'docker build -t agcaaekrem/docker-demo .'
       sh 'docker image list'
    }   
   
     stage("Docker Push"){
        withCredentials([string(credentialsId: 'DOCKER_HUB_PASSWORD', variable: 'DOCKER_HUB_PASSWORD')]) {
         sh "docker login -u agcaaekrem -p ${DOCKER_HUB_PASSWORD}"
        }
        sh "docker push agcaaekrem/docker-demo"
        
    }
     stage("Deploy To Kuberates Cluster"){
         sh "kubectl apply -f k8sSpringbootDeployment.yml"
    }
    
}
