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
#### SSH/Telnet uygulamasına bağlanma;
- ssh -i komutuyla beraber daha önce indirdiğimiz Ssh Key'imizin dosya komutu ekliyoruz ve devamında ubuntu@<VM_Public_Key> ile Server'ın Public Key'i ile birlikte giriş yapıyoruz.



https://user-images.githubusercontent.com/64022432/198405255-db1e52ae-ec34-4a03-9c9c-2fe13a5178e8.mp4

----
----

#### Bir Kubernetes cluster’ı içinde iki farklı kaynak mevcut; master ve node. İki farklı sanal makine oluşturup, ortak kurulumları tamamlayıp, ileriki adımlarda master ve node’u özelleştirerek hedefe ulaşabiliriz.Bu yüzden kurulum adımlarını Master ve Node için , Master için ,Node için şeklinde ayıracağım.

## ~ Master Ve Node İçin Ortak Uygulanacaklar ~

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
  
## ~ Sadece Master Server için uygulanacaklar ~
#### Bu işlemler tamamlandıktan sonra, Kubernetes cluster sistemini oluşturmak için gerekli paketlere sahip duruma gelmiş olduk. Cluster sistemini kurmak için kubeadm init komutunu kullanacağız. Bu komuta verilen iki parametre var. Init işleminden önce bu parametrelerin değerlerini belirlememiz gerekiyor.

#### 1- --apiserver-advertise-address=<ip-address>

#### Bu adres, Kubernetes master sunucusunun gelen istekleri dinleyeceği IP’dir. Değer verilmezse default ile ilişkilendirilen interface kullanılır.Benim için bu değer vm’in IP’si olacak: --apiserver-advertise-address=172.31.10.85

#### 2- --pod-network-cidr Bu parametre sistemde kurulacak olan network modülüne göre (CNI) değer alır.Kubernetes kurulum sırasında bir ağ çözümü sağlamaz. 3. parti bir çözüm kurmanızı bekler. --pod-network-cidr parametresi işte bu seçilen 3. parti network modülüne göre belirlenir. Örneğin ben Weave Network Provider ile ilerliyorum. Bu yüzden parametremiz şu olacak: --pod-network-cidr=192.168.0.0/16
  
#### Böylece init komutumuz şu hale gelmiş oluyor:
> kubeadm init --apiserver-advertise-address=172.31.10.85 --pod-network-cidr=192.168.0.0/16
  
#### Kubernetes cluster sisteminde master sunucu bu komut ile ayaklandırılır. Bu komutun çıktısı çok önemlidir, bu yüzden komut çıktısını mutlaka saklayın. Komut çıktısında üç tane önemli bilgi yer alır. Bunlar:

 1- Master sunucuda kubectl komutunu kullanabilmek için gerekli çevresel değişken tanımlarının nasıl yapıldığı.Yani çıktıda da yazdığı gibi normal bir kullanıcı olarak çalıştırmamız gerekiyor. Hala su modunda iseniz exit ile normal kullanıcıya geçelim.
  
> To start using your cluster, you need to run the following as a regular user:

> exit

> mkdir -p $HOME/.kube

> sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

> sudo chown $(id -u):$(id -g) $HOME/.kube/config
  

2- Bu işlemden sonra bir network modülü kurulmasının gerekliliği

" You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
https://kubernetes.io/docs/concepts/cluster-administration/addons/
"
#### Burada verilen linke giderek ulaştıüınız sayfadan kurulum bilgisi alabilirsiniz. Weave’i şöyle kuruyoruz:
> $ kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

#### 3- Sisteme worker node eklerken kullanılacak token bilgisini içeren komut.
  
"You can now join any number of machines by running the following on each node
as root:"

> kubeadm join 172.31.10.85:6443 --token bmgulk.dy8uqqalhy5wtisi --discovery-token-ca-cert-hash sha256:e277992ec25fc2007c98c44a43986fa8f8fa9eb63b193080748be31d3d98a771
  
#### komutu bir yere kopyalamanızda fayda var. Bu komut cluster’a node eklerken node’lar üzerinden çalıştıracağımız komut.Ancak herhangi bir nedenden dolayı bu çıktıya ulaşamıyorsanız.Token ve ca cert hash bilgisi için aşağıdaki komutları koşabilirsiniz.
  
> kubeadm token list

> openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
  
## ~ Sadece Node Server için uygulanacaklar ~

#### Master node'a yazdığımız ve saklamamız gerektğini söylediğim kubeadm init komutunun çıktısını aynen buraya yapıştırıyoruz.
> kubeadm join 172.31.10.85:6443 --token bmgulk.dy8uqqalhy5wtisi --discovery-token-ca-cert-hash sha256:e277992ec25fc2007c98c44a43986fa8f8fa9eb63b193080748be31d3d98a771

#### Bu çıktı sonunda beklediğimiz Node'un Cluster'a bağlabilmesi.Yani komutun sonunda aşağıdaki çıktıyı almayı bekliyoruz.

![Screenshot 2022-10-28 003840](https://user-images.githubusercontent.com/64022432/198403421-1a5cce1c-dd99-485f-b640-5027e9efe88f.png)

-----

  
#### Sonrasında Master Node'a ilerleyerek aşağıdaki komutu yazıyoruz ve Cluster'ımızın oluştuğunu gözlemliyoruz.

  
> kubectl get nodes

  
  
![Screenshot 2022-10-28 003149](https://user-images.githubusercontent.com/64022432/198403777-9869ae9c-9a2a-4425-9935-9ac50d2a294d.png)
  

### Cluster'ımız oluştu.Şu an için Server-1(Master node) ve Server-2(Worker node) ile işimiz bitti.Jenkins Server'ın kurulumuna geçebiliriz. 
  

  ## ~ Jenkins Server Kurulumu ~

#### İş paketimizin 3.adımına geldik.Son VM'imizide kurup sonrasında süreçleri otomatize etmeye çalışacağız.
#### Jenkins, açık kaynaklı bir otomasyon sunucusudur. Yazılım geliştirmenin oluşturma, test etme ve dağıtma ile ilgili bölümlerini otomatikleştirmeye yardımcı olur,  sürekli entegrasyon ve sürekli teslimatı kolaylaştırır.Hızlıca Kurulum komutlarına geçelim;
  
#### Jenkins bir Java uygulaması olduğu için ilk adım Java'yı yüklemektir. Paket dizinini güncelleyin ve Java 11 OpenJDK paketini aşağıdaki komutlarla yükleyelim: 
  
  > sudo apt update
  > sudo apt install openjdk-11-jre-headless
  
#### Aşağıdaki wget komutunu kullanarak Jenkins deposunun GPG anahtarlarını içe aktarıyoruz: 
  > wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
  
#### Ardından, Jenkins deposunu sisteme ekliyoruz:
  > sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ >
/etc/apt/sources.list.d/jenkins.list'
  
 #### Jenkins deposu etkinleştirildiğinde, apt paket listesini güncelliyoruz ve ardından Jenkins'in en son sürümünü yüklüyoruz:
 >sudo apt update
 
 >sudo apt install jenkins
  
#### Jenkins kurulumunu tamamlamak için tarayıcımızı açıyoruz, IP adresimizi yazıyoruz(Jenkin Server Public_ip) 8080 numaralı bağlantı noktasını AWS güvenlik gruplarında açtığınızdan emin oluyoruz. ~ http://VM_Public_ip:8080 ~ ve aşağıdakine benzer bir ekran görüntülenecektir: 
 
![Screenshot 2022-10-28 011847](https://user-images.githubusercontent.com/64022432/198408803-f3134476-515d-4928-a1d2-c8b9d21a15f6.png)
  
#### Yükleme sırasında Jenkins yükleyicisi, başlangıçta 32 karakter uzunluğunda bir alfasayısal(alphanumeric) bir şifre girmemizi istiyor.Parolaya ulaşmak için görselde de görüldüğü gibi aşağıdaki komutu yazıyoruz:  
> sudo cat /var/lib/jenkins/secrets/initialAdminPassword

> Çıktı : 2115173b548f4e99a203ee99a8732a32 --> bu değeri Jenkins'in Dashboard'ı üzerinde ilgili yere yapıştırıyoruz.
  
#### İlerledikten sonra karşımıza aşağıdaki kısım çıkıyor.Install Suggested Plugins(Önerilen pluginler) seçeneğiyle devam ediyoruz.Jenkins içerisinde Manage Plugins  sekmesinden sonrasında ihtiyaç duyduğumuz pluginleri indirebiliriz.

![Screenshot 2022-10-28 013133](https://user-images.githubusercontent.com/64022432/198410390-31171ede-5891-4281-a705-3d187c521720.png)

#### Pluginleri yükledikten sonra girş ekranı bizi karşılıyor olacak buradan kullanıcı ve şifre oluşturarak giriş yapabiliriz.Ben direk admin olarak giriş yaptım ve kullanıcı ayarları kısmından admin şifresini değiştirdim.
 

![Screenshot 2022-10-28 013322](https://user-images.githubusercontent.com/64022432/198410566-ccc9ad13-bb28-46f7-ba9d-c0dddf72749c.png)

-----
#### Docker yükleme kısmına geldik.Docker'ı yüklerken dikkat etmemiz gerek bir konu var oda Jenkins User'ı Docker grubuna eklemek.Yoksa Jenkins içerisinde Docker komutlarını kullanamayız.
> curl -fsSL get.docker.com | /bin/bash

#### Jenkins User'ı Docker grubuna ekliyoruz:
>sudo usermod -aG docker jenkins
  
#### Son olarak Jenkins'i yeniden başlatıyoruz:
>sudo systemctl restart jenkins
