# Deploy to Kubernetes from Jenkins Pipeline
------------------

![image](https://drive.google.com/uc?export=view&id=1WYcJkq1XVNcWxTJSp_BJ0W8cwu8-Muyj)

----
## Kullanılan araç ve teknolojiler:
- IDE --> Aws Ec2
- Linux --> Ubuntu 20.04
- Kubernetes
- Jenkins
- Docker
- Java 11
- Maven
- MobaXterm

----
Kubernetes üzerine pratik yapmak için elbette en iyi yol bir Kubernetes cluster sistemi üzerinde çalışmak.Böyle bir sistem üzerinde çalışmanın birkaç yolu var.Bu yazıda anlatacağım yol da kendi Cluster Lab'ımızı kurmak. Bu yöntem diğerlerine göre ek iş gerektirse de kurulumun mantığını anlamak için diğerlerine göre daha verimli bir yol.Tek bir makine üzerinde bir Kubernetes cluster oluşturabilmek için bir sanallaştırma aracına ihtiyaç var. Ben AWS Ec2 kullanacağım.Ancak kurulum adımları bir çok farklı sanallaştırma aracı için de geçerli.

## Kurulum
#### Kurulumda adım adım ilerleyeceğim maddeler halinde açıklayacak olursam:
1. Ubuntu 20.04 ile 3 VM oluşturacağım 3 VM'i ilerleyen adımlarda kuracağım.
2. 1 Master ve 1 Node içeren Kubernetes Cluster'ı kurulumu (Server-1 ve Server-2)
3. Server-3'te Jenkins kurulumu
4. Server-3'te Docker registry kurulumu
5. Jenkins pipeline oluşturma:   
a. Dockerfile ile bir uygulama görüntüsü(image) oluşturma.
b. Server-3'e kurduğumuz Docker Registry'e Docker Image'ımızı itiyoruz(Push).
c. Bu Docker Image'ı Kubernetes Cluster'ımıza dağıtıyoruz(Deploy).

a-b-c adımlarımızı Jenkinsfile içinde kuracağız.Yani dışarıdan bir müdahele yapmadan tüm bu süreçler otomatize olacak.

----
#### Aws üzerinde örnek Ec2 instance açılımı;
- Genel önerilen minimum gereksinimler: Master ve Jenkins serverları için; 2gb Ram + 2 Cpu -- Node için; 1 gb Ram + 1 Cpu.
- Burada ssh key tanımlaması yapıyoruz.Aws üzerinde çalışırken bir  SSH/Telnet uygulamasına ihtiyacınız olacak.Ben MobaXterm kullanıyor olacağım.
- Security grubunda açacağımız portları belirliyoruz.Eğer denemek içinse ve güvenlik kritiğiniz değilse Inbound Securtiy grubunda tüm trafiğe izin verebilirsiniz.

https://user-images.githubusercontent.com/64022432/198392563-c1000fc7-af6f-4c27-b0b0-d7c3930eb045.mp4

----

Bir Kubernetes cluster’ı içinde iki farklı kaynak mevcut; master ve node. İki farklı sanal makine oluşturup, ortak kurulumları tamamlayıp, ileriki adımlarda master ve node’u özelleştirerek hedefe ulaşabiliriz.Bu yüzden kurulum adımlarını Master ve Node için , Master için ,Node için şeklinde ayıracağım.
## Master Ve Node İçin Ortak Uygulanacaklar:

#### Kubernetes kurulumu yaparken dikkat edeceğimiz ilk nokta swap alanını iptal etmek.Kubernetes swap alan varken çalışmıyor. Bunun için aşağıdaki komutu kullanabiliriz. Ancak sunucu reboot edildiğinde swap alan tekrar aktive olacaktır ve k8s servisi ayaklanırken hata verecektir. Bu yüzden swap alanını /etc/fstab dosyasına nano,vi veya vim ile girerek swap alanının olduğu satırı yoruma alabilirsiniz.

> root@172.31.10.85:~# swapoff -a

#### Kubernetes bir container orchestrator olduğu için elbette bir container runtime uygulamasına ihtiyacımız var. Şu anda K8s’in desteklediği runtime’lar arasında rkt, cri-o, containerd ve frakti uygulamaları olsa da varsayılan olarak kullanılan uygulama docker. Sistemimize docker’ı kuruyoruz.

> apt-get update && apt-get install -y docker.io

#### Şimdi sıra Kubernetes uygulamalarını kurmakta. Bu uygulamalar şunlar:
- kubeadm (kubernetes cluster önyükleyicisi)
- kubelet (pod’ları ve container’ları ayaklandırır)
- kubectl (kubernetes cluster ile iletişim aracı).

#### curl ve apt-transport-https paketlerinin kurulumu:
> apt-get update

> apt-get install -y apt-transport-https curl

#### Kubernetes için apt-key değerinin alınması
> curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

#### Ubuntu için kubernetes kaynak bilgilerinin /etc/apt/sources.list.d altına eklenmesi
> cat <<EOF >/etc/apt/sources.list.d/kubernetes.list deb http://apt.kubernetes.io/ kubernetes-xenial main EOF

> deb http://apt.kubernetes.io/ kubernetes-xenial main

> EOF
  
#### Yeni kaynaklara göre paket listesinin güncellenmesi ve kurulması. 
- Hold içeren komut ile paketlerin güncellenmesini engelleriz.

> apt-get update

> apt-get install -y kubelet kubeadm kubectl

> apt-mark hold kubelet kubeadm kubectl
