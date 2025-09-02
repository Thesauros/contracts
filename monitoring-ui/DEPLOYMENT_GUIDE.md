# 🚀 Thesauros Monitoring Service - Deployment Guide

## 📋 Prerequisites

### 1. Hetzner Cloud Account
- Создайте аккаунт на [Hetzner Cloud](https://cloud.hetzner.com/)
- Получите API Token в панели управления

### 2. Domain Name
- Купите домен (например, `your-domain.com`)
- Настройте DNS записи

### 3. Local Tools
```bash
# Установите необходимые инструменты
brew install docker kubectl terraform

# Или для Ubuntu/Debian
sudo apt update
sudo apt install docker.io kubectl terraform
```

## 🏗️ Step-by-Step Deployment

### Step 1: Подготовка проекта

```bash
# Клонируйте репозиторий
git clone <your-repo-url>
cd contracts/monitoring-ui

# Установите зависимости
npm install

# Создайте production environment файл
cp .env.example .env.production
```

### Step 2: Настройка Terraform

```bash
cd terraform

# Создайте terraform.tfvars
cat > terraform.tfvars << EOF
hcloud_token = "your-hetzner-api-token"
domain_name = "monitoring.your-domain.com"
environment = "prod"
EOF

# Инициализируйте Terraform
terraform init

# Планируйте инфраструктуру
terraform plan

# Создайте инфраструктуру
terraform apply
```

### Step 3: Настройка Kubernetes

```bash
# Получите kubeconfig
terraform output -raw kubeconfig > ~/.kube/config

# Установите nginx-ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Установите cert-manager для SSL
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### Step 4: Настройка Secrets

```bash
# Создайте Kubernetes secrets
kubectl create secret generic thesauros-secrets \
  --from-literal=arbitrum-rpc-url="https://arb1.arbitrum.io/rpc" \
  --from-literal=allowed-origins="https://monitoring.your-domain.com"
```

### Step 5: Сборка и деплой Docker образа

```bash
# Соберите Docker образ
docker build -t thesauros/monitoring-ui:latest .

# Загрузите в registry (GitHub Container Registry)
docker tag thesauros/monitoring-ui:latest ghcr.io/your-username/thesauros-monitoring:latest
docker push ghcr.io/your-username/thesauros-monitoring:latest
```

### Step 6: Деплой в Kubernetes

```bash
# Обновите image в deployment.yaml
sed -i 's|image: .*|image: ghcr.io/your-username/thesauros-monitoring:latest|' k8s/deployment.yaml

# Примените манифесты
kubectl apply -f k8s/deployment.yaml

# Проверьте статус
kubectl get pods -l app=thesauros-monitoring
kubectl get services -l app=thesauros-monitoring
```

### Step 7: Настройка DNS

```bash
# Получите IP адрес load balancer
kubectl get service thesauros-monitoring-service

# Добавьте A запись в DNS:
# monitoring.your-domain.com -> <load-balancer-ip>
```

### Step 8: Настройка SSL

```bash
# Создайте ClusterIssuer для Let's Encrypt
cat > cluster-issuer.yaml << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@domain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

kubectl apply -f cluster-issuer.yaml
```

## 🔧 Automation Scripts

### Быстрый деплой
```bash
# Используйте автоматический скрипт
chmod +x deploy.sh
./deploy.sh
```

### GitHub Actions (CI/CD)
```bash
# Настройте secrets в GitHub:
# HCLOUD_TOKEN
# KUBE_CONFIG (base64 encoded)

# Push в main branch запустит автоматический деплой
git push origin main
```

## 📊 Monitoring & Maintenance

### Проверка статуса
```bash
# Проверьте pods
kubectl get pods -l app=thesauros-monitoring

# Проверьте логи
kubectl logs -l app=thesauros-monitoring

# Проверьте сервис
curl https://monitoring.your-domain.com/api/health
```

### Обновление
```bash
# Обновите образ
docker build -t thesauros/monitoring-ui:latest .
docker push thesauros/monitoring-ui:latest

# Обновите deployment
kubectl rollout restart deployment/thesauros-monitoring
```

### Масштабирование
```bash
# Увеличьте количество реплик
kubectl scale deployment thesauros-monitoring --replicas=3
```

## 🔒 Security Checklist

- [ ] HTTPS настроен
- [ ] Rate limiting включен
- [ ] Security headers настроены
- [ ] Secrets зашифрованы
- [ ] Firewall настроен
- [ ] Monitoring включен
- [ ] Backup настроен

## 💰 Cost Estimation

**Hetzner Cloud (месячно):**
- Kubernetes Cluster (cx21 x 2): ~$20
- Load Balancer: ~$10
- Network & Storage: ~$5
- **Total: ~$35/month**

## 🆘 Troubleshooting

### Common Issues

1. **Pod не запускается**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

2. **SSL не работает**
```bash
kubectl get certificates
kubectl describe certificate thesauros-monitoring-tls
```

3. **DNS не резолвится**
```bash
nslookup monitoring.your-domain.com
dig monitoring.your-domain.com
```

### Support
- [Hetzner Cloud Documentation](https://docs.hetzner.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://www.terraform.io/docs/)
