#!/bin/bash
IP=$1
ETCD_ENDPOINTS=$2
KUBE_ETC=/etc/kubernetes
KUBE_API_CONF=/etc/kubernetes/apiserver.conf
cp /etc/kubernetes/kubernetes/server/bin/{kube-apiserver,kube-scheduler,kube-controller-manager} /usr/local/bin/
 
mkdir -p $KUBE_ETC
 
# Create a token file.
cat>$KUBE_ETC/token.csv<<EOF
$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
 
# Create a kube-apiserver configuration file.
cat >$KUBE_API_CONF<<EOF
KUBE_APISERVER_OPTS="--logtostderr=true \\
--v=4 \\
--etcd-servers=$ETCD_ENDPOINTS \\
--bind-address=$IP \\
--secure-port=6443 \\
--advertise-address=$IP \\
--allow-privileged=true \\
--service-cluster-ip-range=10.0.0.0/24 \\
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,NodeRestriction \\
--authorization-mode=RBAC,Node \\
--enable-bootstrap-token-auth \\
--token-auth-file=$KUBE_ETC/token.csv \\
--service-node-port-range=30000-50000 \\
--tls-cert-file=$KUBE_ETC/ssl/server.pem  \\
--tls-private-key-file=$KUBE_ETC/ssl/server-key.pem \\
--client-ca-file=$KUBE_ETC/ssl/ca.pem \\
--service-account-key-file=$KUBE_ETC/ssl/ca-key.pem \\
--kubelet-client-certificate=/etc/kubernetes/ssl/admin.pem \\
--kubelet-client-key=/etc/kubernetes/ssl/admin-key.pem \\
--etcd-cafile=/etc/etcd/ssl/ca.pem \\
--etcd-certfile=/etc/etcd/ssl/server.pem \\
--etcd-keyfile=/etc/etcd/ssl/server-key.pem"
EOF
 
# Create the kube-apiserver service.
cat>/usr/lib/systemd/system/kube-apiserver.service<<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service
 
[Service]
EnvironmentFile=-$KUBE_API_CONF
ExecStart=/usr/local/bin/kube-apiserver \$KUBE_APISERVER_OPTS
Restart=on-failure
 
[Install]
WantedBy=multi-user.target
EOF
 
