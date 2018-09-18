#!/bin/bash
set -ex
DEFAULT_CNI=flannel
DEFAULT_HA=nginx
DEFAULT_PROXY=iptables
DEFAULT_VERSION=v1.11.1
DEFAULT_REUSE=true
show_help () {
cat << USAGE
usage: $0 [ -m MASTER(S) ] [ -n NODE(S) ] [ -i VIRTUAL-IP ] [ -p PASSORD ]
       [ -c CNI ] [ -a HA-STRATEGY ] [ -x PROXY-STATEGY ] [ -v KUBE-VERSION ]
       [ -r REUSE-MASTER-AS-NODE ] [ -k SCKEY ]
       [ -b BRANCH ] [ -s SCRIPT-BRANCH ]
use to deploy Kubernetes.
    -m : Specify the IP address(es) of Master node(s). If multiple, set the masters in term of csv, 
         as 'master-ip-1,master-ip-2,master-ip-3'.
    -p : Specify the uniform password of hosts. 
    advanced setting:
    -n : Specify the IP address(es) of Node node(s). If multiple, set the nodes in term of csv, 
         as 'node-ip-1,node-ip-2,node-ip-3'.
         If not specified, no nodes would be installed.
    -a : Specify the HA strategy, for instance: "nginx" or "vip".  
         If not specified, use "$DEFAULT_HA" by default.
    -i : Specify the virtual IP address. 
    -c : Specify the CNI strategy, for instance: "flannel" or "calico".  
         If not specified, use "$DEFAULT_CNI" by default.
    -x : Specify the proxy strategy, for instance: "iptables" or "ipvs".  
         If not specified, use "$DEFAULT_PROXY" by default.
    -v : Specify the version of Kubernetes to install.  
         If not specified, install "$DEFAULT_VERSION" by default.
    -r : Define if reusing master as node, which means installing node components on master or not.
         If not specified, reuse master as node by default. 
    -k : Specify the SCKEY of the user to send note to. If multiple, set the keys in term of csv, 
         as 'key-1,key-2,key-3'. 
    debug setting:
    -b : Specify the branch of code. 
         If not specified, use "master" by default.
    -s : Specify the branch of stage scripts. 
         If not specified, set the value of -b by default.
This script should run on a Master (to be) node.
USAGE
exit 0
}
# Get Opts
while getopts "hm:p:n:a:i:c:x:v:rk:b:s:" opt; do # 选项后面的冒号表示该选项需要参数
    case "$opt" in
    h)  show_help
        ;;
    m)  MASTER=$OPTARG # 参数存在$OPTARG中
        ;;
    i)  VIP=$OPTARG
        ;;
    n)  ONLY_NODE=$OPTARG
        ;;
    p)  PASSWD=$OPTARG
        ;;
    c)  CNI=$OPTARG
        ;;
    a)  HA=$OPTARG
        ;;
    x)  PROXY=$OPTARG
        ;;
    v)  VERSION=$OPTARG
        ;;
    b)  BRANCH=$OPTARG
        ;;
    s)  STAGES_BRANCH=$OPTARG
        ;;
    r)  REUSE=false 
        ;;
    k)  SCKEY=$OPTARG
        ;;
    ?)  # 当有不认识的选项的时候arg为?
        echo "unkonw argument"
        exit 1
        ;;
    esac
done
[ -z "$*" ] && show_help
CNI=${CNI:-"${DEFAULT_CNI}"}
HA=${HA:-"${DEFAULT_HA}"}
VERSION=${VERSION:-"${DEFAULT_VERSION}"}
BRANCH=${BRANCH:-"master"}
STAGES_BRANCH=${STAGES_BRANCH:-"${BRANCH}"}
PROXY=${PROXY:-"${DEFAULT_PROXY}"}
REUSE=${REUSE:-"${DEFAULT_REUSE}"}
chk_var () {
if [ -z "$2" ]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no input for \"$1\", try \"$0 -h\"."
  sleep 3
  exit 1
fi
}
chk_var -m $MASTER
[[ "vip" == "${HA}" ]] && chk_var -v $VIP
chk_var -p $PASSWD
if ! ${REUSE}; then
  chk_var -n ${ONLY_NODE}
fi
# 0 set env
START=$(date +%s)
WAIT=3
STAGE=0
STAGE_FILE=stage.init
ANSIBLE_GROUP=k8s
MASTER_GROUP=master
NODE_GROUP=node
ONLY_GROUP=only
if [ ! -f ./${STAGE_FILE} ]; then
  touch ./${STAGE_FILE}
  echo 0 > ./${STAGE_FILE} 
fi
getScript () {
  TRY=10
  URL=$1
  SCRIPT=$2
  for i in $(seq -s " " 1 ${TRY}); do
    curl -s -o ./$SCRIPT $URL/$SCRIPT
    if cat ./$SCRIPT | grep "^404: Not Found"; then
      rm -f ./$SCRIPT
    else
      break
    fi
  done
  if [ -f "./$SCRIPT" ]; then
    chmod +x ./$SCRIPT
  else
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - downloading failed !!!" 
    echo " - $URL/$SCRIPT"
    echo " - Please check !!!"
    sleep 3
    exit 1
  fi
}
PROJECT="ikube"
STAGES=https://raw.githubusercontent.com/humstarman/${PROJECT}-stages/${STAGES_BRANCH}
SCRIPTS=https://raw.githubusercontent.com/humstarman/${PROJECT}-scripts/${BRANCH}
MANIFESTS=https://raw.githubusercontent.com/humstarman/${PROJECT}-manifests/${BRANCH}
VERSION=https://raw.githubusercontent.com/humstarman/${PROJECT}-version/${VERSION}
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - checking environment ... "
  # check curl & 
  if [ ! -x "$(command -v curl)" ]; then
    if [ -x "$(command -v yum)" ]; then
      yum makecache fast
      yum install -y curl
    fi
    if [ -x "$(command -v apt-get)" ]; then
      apt-get update
      apt-get install -y curl
    fi
  fi
  curl -s -O ${VERSION}/version
  curl -s $SCRIPTS/check-ansible.sh | /bin/bash
  echo $MASTER > ./${MASTER_GROUP}.csv
  MASTER=$(echo $MASTER | tr "," " ")
  #echo $MASTER
  N_MASTER=$(echo $MASTER | wc -w)
  #echo $N_MASTER
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $N_MASTER masters: $(cat ./${MASTER_GROUP}.csv)."
  if ${REUSE}; then
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - reuse master as node."
    if [ -z "$ONLY_NODE" ]; then
      NODE=$(cat ./${MASTER_GROUP}.csv)
    else
      NODE=$(cat ./${MASTER_GROUP}.csv),${ONLY_NODE}
    fi
  else
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - NOT reuse master as node."
    NODE=${ONLY_NODE}
  fi
  if [ -z "$NODE" ]; then
    NODE_EXISTENCE=false
  else
    NODE_EXISTENCE=true
    echo $NODE > ./${NODE_GROUP}.csv
  fi
  if [ -z "${ONLY_NODE}" ]; then
    ONLY_NODE_EXISTENCE=false
  else
    ONLY_NODE_EXISTENCE=true
    echo ${ONLY_NODE} > ./${ONLY_GROUP}.csv
    ONLY_NODE=$(echo $ONLY_NODE | tr "," " ")
  fi
  if $NODE_EXISTENCE; then
    NODE=$(echo $NODE | tr "," " ")
    #echo ${NODE}
    N_NODE=$(echo $NODE | wc -w)
    #echo $N_NODE
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $N_NODE nodes: $(cat ./${NODE_GROUP}.csv)."
  else
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - no node to install."
  fi
  if [ -n "$VIP" ]; then
    echo $VIP > ./vip.info
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - virtual IP: $(cat ./vip.info)."
  fi
  echo $PASSWD > ./passwd.log
  # mk env file
  FILE=info.env
  if [ ! -f "$FILE" ]; then
    cat > $FILE << EOF
export MASTER="$MASTER"
export N_MASTER=$N_MASTER
export NODE_EXISTENCE=$NODE_EXISTENCE
export NODE="$NODE"
export ONLY_NODE="$ONLY_NODE"
export N_NODE=$N_NODE
export VIP=$VIP
export SCRIPTS=${SCRIPTS}
export STAGES=${STAGES}
export MANIFESTS=${MANIFESTS}
export ANSIBLE_GROUP=${ANSIBLE_GROUP}
export HA=${HA}
export CNI=${CNI}
export PROXY=${PROXY}
export VERSION=${VERSION}
export REUSE=${REUSE}
export NODE_GROUP=${NODE_GROUP}
export MASTER_GROUP=${MASTER_GROUP}
export ONLY_GROUP=${ONLY_GROUP}
export ONLY_NODE_EXISTENCE=${ONLY_NODE_EXISTENCE}
EOF
  fi
  curl -s $SCRIPTS/mk-ansible-available.sh | /bin/bash
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - connectivity checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - environment checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare to install."
  ## 1 stop selinux
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - shutdown Selinux."
  getScript $SCRIPTS shutdown-selinux.sh
  ansible ${ANSIBLE_GROUP} -m script -a ./shutdown-selinux.sh
  ## 2 stop firewall
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - stop firewall."
  getScript $SCRIPTS stop-firewall.sh
  ansible ${ANSIBLE_GROUP} -m script -a ./stop-firewall.sh
  ## 3 mkdirs
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare directories."
  getScript $SCRIPTS batch-mkdir.sh
  ansible ${ANSIBLE_GROUP} -m script -a ./batch-mkdir.sh
fi

# 1 environment variables
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - config cluster environment variables ... "
  curl -s $STAGES/cluster-environment-variables.sh | /bin/bash
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cluster environment variables configured. "
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 generate CA pem
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  curl -s $STAGES/generate-ca-pem.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 deploy ha etcd cluster
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  curl -s $STAGES/deploy-etcd.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 prepare kubernetes 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  curl -s $STAGES/install-k8s.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# 5 deploy kubectl
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  curl -s $STAGES/deploy-kubectl.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# 6 deploy flanneld
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  if [[ "flannel" == "$CNI" ]]; then
    curl -s $STAGES/deploy-flanneld.sh | /bin/bash
  fi
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 7 deploy master 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  curl -s $STAGES/deploy-master.sh | /bin/bash
  if [[ "vip" == "$HA" ]]; then
    curl -s $STAGES/deploy-vip-ha.sh | /bin/bash
  fi
  echo $STAGE > ./${STAGE_FILE}
fi

# 8 deploy node
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  curl -s $STAGES/deploy-node.sh | /bin/bash
  if [[ "nginx" == "$HA" ]]; then
    curl -s $STAGES/deploy-nginx-ha.sh | /bin/bash
  fi
  echo $STAGE > ./${STAGE_FILE}
fi

# 9 deploy calico 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  if [[ "calico" == "$CNI" ]]; then
    curl -s $STAGES/deploy-calico.sh | /bin/bash
  fi
  echo $STAGE > ./${STAGE_FILE}
fi

# 10 approve certificate
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - approve certificate:"
  curl -s $SCRIPTS/approve-pem.sh | /bin/bash
  FILE=approve-pem.sh
  cat > $FILE <<"EOF"
#!/bin/bash
CSRS=$(kubectl get csr | grep Pending | awk -F ' ' '{print $1}')
if [ -n "$CSRS" ]; then
  for CSR in $CSRS; do
    kubectl certificate approve $CSR
  done
fi
EOF
  chmod +x $FILE
  echo $STAGE > ./${STAGE_FILE}
fi

# 11 clearance 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" -lt "$STAGE" ]]; then
  [ -f "./${NODE_GROUP}.csv" ] || touch ${NODE_GROUP}.csv
  curl -s $SCRIPTS/clearance.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# ending
MASTER=$(sed s/","/" "/g ./${MASTER_GROUP}.csv)
N_MASTER=$(echo $MASTER | wc -w)
if [ ! -f ./${NODE_GROUP}.csv ]; then
  N_NODE=0
else
  NODE=$(cat ./${NODE_GROUP}.csv | tr "," " ")
  N_NODE=$(echo $NODE | wc -w)
  [ -z "$N_NODE" ] && N_NODE=0
fi 
TOTAL=$[${N_MASTER}+${N_NODE}]
END=$(date +%s)
ELAPSED=$[$END-$START]
MINUTE=$[$ELAPSED/60]
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - summary: "
echo " - Kubernetes installation elapsed: $ELAPSED sec, approximately $MINUTE ~ $[$MINUTE+1] min."
echo " - Kubernetes paltform: "
echo " - Total nodes: $TOTAL"
echo " - With masters: $N_MASTER"
## make backup
THIS_DIR=$(cd "$(dirname "$0")";pwd)
curl -s $SCRIPTS/mk-backup.sh | /bin/bash
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - backup important info from $THIS_DIR to /var/k8s/bak."
if [ -n "${SCKEY}" ]; then
  SCKEY=$(echo ${SCKEY} | tr "," " ")
  TEXT="finished install kubernetes"
  DESP=$(cat <<EOF
at $(date -d today +'%Y-%m-%d %H:%M:%S')  
elapsed: $ELAPSED sec, approximately $MINUTE ~ $[$MINUTE+1] min
EOF
  )
  for KEY in ${SCKEY}; do
    URL=https://sc.ftqq.com/${KEY}.send
    curl -d "text=${TEXT}&desp=${DESP}" -X POST ${URL}
  done
fi
sleep $WAIT 
exit 0