#!/usr/bin/env bash
set -euo pipefail

PRIMARY_EKS_HOST="eks.dr.vaultrix.in"
DR_EKS_HOST="eks-dr.dr.vaultrix.in"
PRIMARY_EC2_HOST="ec2.dr.vaultrix.in"
DR_EC2_HOST="ec2-dr.dr.vaultrix.in"
HOSTED_ZONE="dr.vaultrix.in"
DR_REGION="ap-southeast-1"
PRIMARY_REGION="ap-south-1"

hosted_zone_id() {
  aws route53 list-hosted-zones-by-name \
    --dns-name "${HOSTED_ZONE}" \
    --query 'HostedZones[?Name==`dr.vaultrix.in.`].Id | [0]' \
    --output text
}

record_target() {
  local zone_id="$1"
  local name="$2"
  aws route53 list-resource-record-sets \
    --hosted-zone-id "${zone_id}" \
    --query "ResourceRecordSets[?Name==\`${name}.\`].ResourceRecords[0].Value | [0]" \
    --output text
}

require_target() {
  [[ -n "$1" && "$1" != "None" ]]
}

canonical_notes() {
  jq -c 'map({title,content}) | sort_by(.title,.content)' "$1"
}

reverse_sync_eks() {
  local dr_target="$1"
  local primary_target="$2"
  local before_file="${RUNNER_TEMP}/eks-dr-before-failback.json"
  local after_file="${RUNNER_TEMP}/eks-dr-after-sync.json"
  local primary_file="${RUNNER_TEMP}/eks-primary-before-sync.json"
  local verified_file="${RUNNER_TEMP}/eks-primary-after-sync.json"
  local note title content key existing_keys

  echo "Capturing the authoritative DR notes before EKS failback."
  curl --fail --retry 12 --retry-delay 5 -H "Host: ${PRIMARY_EKS_HOST}" \
    "http://${dr_target}/api/notes" -o "${before_file}"
  curl --fail --retry 12 --retry-delay 5 -H "Host: ${PRIMARY_EKS_HOST}" \
    "http://${primary_target}/api/notes" -o "${primary_file}"
  jq -e 'type == "array"' "${before_file}" >/dev/null
  jq -e 'type == "array"' "${primary_file}" >/dev/null

  existing_keys="$(jq -c '[.[] | [.title,.content] | @json]' "${primary_file}")"
  while IFS= read -r note; do
    key="$(jq -r '[.title,.content] | @json' <<< "${note}")"
    if jq -e --arg key "${key}" 'index($key) != null' <<< "${existing_keys}" >/dev/null; then
      continue
    fi
    title="$(jq -r .title <<< "${note}")"
    content="$(jq -r .content <<< "${note}")"
    curl --fail -H "Host: ${PRIMARY_EKS_HOST}" -H 'Content-Type: application/json' \
      --data "$(jq -cn --arg title "${title}" --arg content "${content}" '{title:$title,content:$content}')" \
      "http://${primary_target}/api/notes" >/dev/null
    existing_keys="$(jq -c --arg key "${key}" '. + [$key]' <<< "${existing_keys}")"
  done < <(jq -c '.[] | {title,content}' "${before_file}")

  curl --fail --retry 6 --retry-delay 3 -H "Host: ${PRIMARY_EKS_HOST}" \
    "http://${dr_target}/api/notes" -o "${after_file}"
  if [[ "$(canonical_notes "${before_file}")" != "$(canonical_notes "${after_file}")" ]]; then
    echo "DR notes changed during reverse synchronization. DNS remains on DR; stop writes and rerun failback." >&2
    return 1
  fi

  curl --fail --retry 6 --retry-delay 3 -H "Host: ${PRIMARY_EKS_HOST}" \
    "http://${primary_target}/api/notes" -o "${verified_file}"
  jq -e --slurpfile dr "${after_file}" '
    ([.[] | [.title,.content] | @json]) as $primary |
    all($dr[0][]; ([.title,.content] | @json) as $key | $primary | index($key) != null)
  ' "${verified_file}" >/dev/null

  echo "Verified that every DR note exists in primary. IDs and timestamps are intentionally regenerated."
}

capture_eks_snapshot() {
  curl --fail --retry 6 --retry-delay 5 "http://${PRIMARY_EKS_HOST}/api/notes" \
    -o "${RUNNER_TEMP}/notes.json"
  jq -e 'type == "array"' "${RUNNER_TEMP}/notes.json"
  echo "Captured $(jq length "${RUNNER_TEMP}/notes.json") primary notes."
}

discover_primary_image() {
  aws eks update-kubeconfig --name vaultrix-dr-primary-eks --region "${PRIMARY_REGION}"
  local image digest
  image="$(kubectl -n notes get deployment notes -o jsonpath='{.spec.template.spec.containers[0].image}')"
  digest="${image##*@}"
  [[ "${digest}" == sha256:* ]]
  echo "digest=${digest}" >> "${GITHUB_OUTPUT}"
}

install_load_balancer_controller() {
  aws eks update-kubeconfig --name vaultrix-dr-dr-eks --region "${DR_REGION}"
  local vpc_id
  vpc_id="$(aws eks describe-cluster --name vaultrix-dr-dr-eks \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text)"
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system --version 3.3.0 \
    --set clusterName=vaultrix-dr-dr-eks \
    --set region="${DR_REGION}" \
    --set vpcId="${vpc_id}" \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set serviceAccount.create=true \
    --wait --timeout 10m
}

create_eks_database_secret() {
  set +x
  local secret_id secret_json password database username encoded_password
  secret_id="vaultrix-dr-dr-eks/notes/database"
  if ! secret_json="$(aws secretsmanager get-secret-value --secret-id "${secret_id}" \
    --query SecretString --output text 2>/dev/null)" || [[ -z "${secret_json}" ]]; then
    password="$(openssl rand -base64 32 | tr -d '\n')"
    secret_json="$(jq -cn --arg database notes --arg username notes --arg password "${password}" \
      '{database:$database,username:$username,password:$password}')"
    aws secretsmanager put-secret-value --secret-id "${secret_id}" \
      --secret-string "${secret_json}" >/dev/null
  fi
  database="$(jq -r .database <<< "${secret_json}")"
  username="$(jq -r .username <<< "${secret_json}")"
  password="$(jq -r .password <<< "${secret_json}")"
  encoded_password="$(jq -rn --arg value "${password}" '$value|@uri')"
  kubectl create namespace notes --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n notes create secret generic notes-database \
    --from-literal="database=${database}" \
    --from-literal="username=${username}" \
    --from-literal="password=${password}" \
    --from-literal="url=postgresql://${username}:${encoded_password}@postgres:5432/${database}" \
    --dry-run=client -o yaml | kubectl apply -f -
  unset password encoded_password secret_json
}

deploy_eks() {
  local digest="$1"
  local alb=""
  sed -i "s|newTag: replace-me|digest: ${digest}|" kubernetes/overlays/dr/kustomization.yaml
  kubectl apply -k kubernetes/overlays/dr
  kubectl -n notes rollout status statefulset/postgres --timeout=10m
  kubectl -n notes rollout status deployment/notes --timeout=10m
  for _ in {1..60}; do
    alb="$(kubectl -n notes get ingress notes -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    [[ -n "${alb}" ]] && break
    sleep 10
  done
  require_target "${alb}"
  curl --fail --retry 30 --retry-delay 10 --retry-all-errors \
    -H "Host: ${PRIMARY_EKS_HOST}" "http://${alb}/healthz"
  echo "hostname=${alb}" >> "${GITHUB_OUTPUT}"
}

seed_eks() {
  local alb="$1"
  curl --fail -H "Host: ${PRIMARY_EKS_HOST}" "http://${alb}/api/notes" |
    jq -r '.[].id' | while read -r id; do
      curl --fail -X DELETE -H "Host: ${PRIMARY_EKS_HOST}" "http://${alb}/api/notes/${id}"
    done
  jq -c '.[] | {title,content}' "${RUNNER_TEMP}/notes.json" | while read -r note; do
    curl --fail -H "Host: ${PRIMARY_EKS_HOST}" -H 'Content-Type: application/json' \
      --data "${note}" "http://${alb}/api/notes" >/dev/null
  done
  local zone_id change
  zone_id="$(hosted_zone_id)"
  change="$(jq -cn --arg target "${alb}" \
    '{Changes:[{Action:"UPSERT",ResourceRecordSet:{Name:"eks-dr.dr.vaultrix.in",Type:"CNAME",TTL:60,ResourceRecords:[{Value:$target}]}}]}')"
  aws route53 change-resource-record-sets --hosted-zone-id "${zone_id}" \
    --change-batch "${change}" >/dev/null
  curl --fail --retry 12 --retry-delay 10 -H "Host: ${PRIMARY_EKS_HOST}" "http://${alb}/api/notes"
}

capture_ec2_snapshot() {
  curl --fail --retry 6 --retry-delay 5 "http://${PRIMARY_EC2_HOST}/api/tasks" \
    -o "${RUNNER_TEMP}/tasks.json"
  jq -e 'type == "array"' "${RUNNER_TEMP}/tasks.json"
  echo "Captured $(jq length "${RUNNER_TEMP}/tasks.json") primary tasks."
}

seed_ec2() {
  local alb status=""
  alb="$(aws elbv2 describe-load-balancers --names vaultrix-dr-dr-ec2-alb \
    --query 'LoadBalancers[0].DNSName' --output text)"
  curl --fail --retry 30 --retry-delay 10 "http://${alb}/health"
  for _ in {1..30}; do
    status="$(curl --fail --silent "http://${alb}/api/status")"
    [[ "$(jq -r .database <<< "${status}")" == connected ]] && break
    sleep 10
  done
  [[ "$(jq -r .database <<< "${status}")" == connected ]]
  curl --fail "http://${alb}/api/tasks" | jq -r '.[].id' | while read -r id; do
    curl --fail -X DELETE "http://${alb}/api/tasks/${id}" >/dev/null
  done
  jq -c '.[] | {title,description,priority}' "${RUNNER_TEMP}/tasks.json" | while read -r task; do
    curl --fail -H 'Content-Type: application/json' --data "${task}" \
      "http://${alb}/api/tasks" >/dev/null
  done
  curl --fail "http://${alb}/api/tasks"
}

cutover_eks() {
  local operation="$1"
  local zone_id dr_target primary_target change change_id
  zone_id="$(hosted_zone_id)"
  dr_target="$(record_target "${zone_id}" "${DR_EKS_HOST}")"
  require_target "${dr_target}"
  curl --fail --retry 12 --retry-delay 5 -H "Host: ${PRIMARY_EKS_HOST}" \
    "http://${dr_target}/healthz"

  if [[ "${operation}" == "Failover to DR" ]]; then
    primary_target="$(record_target "${zone_id}" "${PRIMARY_EKS_HOST}")"
    require_target "${primary_target}"
    change="$(jq -cn --arg primary "${primary_target}" --arg dr "${dr_target}" \
      '{Changes:[{Action:"UPSERT",ResourceRecordSet:{Name:"eks-primary.dr.vaultrix.in",Type:"CNAME",TTL:60,ResourceRecords:[{Value:$primary}]}},{Action:"UPSERT",ResourceRecordSet:{Name:"eks.dr.vaultrix.in",Type:"CNAME",TTL:60,ResourceRecords:[{Value:$dr}]}}]}')"
  else
    primary_target="$(record_target "${zone_id}" "eks-primary.dr.vaultrix.in")"
    require_target "${primary_target}"
    reverse_sync_eks "${dr_target}" "${primary_target}"
    change="$(jq -cn --arg primary "${primary_target}" \
      '{Changes:[{Action:"UPSERT",ResourceRecordSet:{Name:"eks.dr.vaultrix.in",Type:"CNAME",TTL:60,ResourceRecords:[{Value:$primary}]}}]}')"
  fi
  change_id="$(aws route53 change-resource-record-sets --hosted-zone-id "${zone_id}" \
    --change-batch "${change}" --query ChangeInfo.Id --output text)"
  aws route53 wait resource-record-sets-changed --id "${change_id}"
  curl --fail --retry 30 --retry-delay 5 "http://${PRIMARY_EKS_HOST}/healthz"
  curl --fail "http://${PRIMARY_EKS_HOST}/api/notes"
}

validate_dr_ec2() {
  local status
  status="$(curl --fail --retry 12 --retry-delay 5 "http://${DR_EC2_HOST}/api/status")"
  test "$(jq -r .environment <<< "${status}")" = DR
  test "$(jq -r .database <<< "${status}")" = connected
}

cutover_ec2() {
  local operation="$1"
  local desired_state instance_filter instance_id status=""
  if [[ "${operation}" == "Failover to DR" ]]; then
    desired_state=DR
    instance_filter=running
  else
    desired_state=PRIMARY
    instance_filter=stopped
  fi
  instance_id="$(aws ec2 describe-instances \
    --filters 'Name=tag:Name,Values=vaultrix-dr-primary-ec2-instance' \
      "Name=instance-state-name,Values=${instance_filter}" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text)"
  require_target "${instance_id}"
  if [[ "${operation}" == "Failover to DR" ]]; then
    aws ec2 stop-instances --instance-ids "${instance_id}" >/dev/null
    aws ec2 wait instance-stopped --instance-ids "${instance_id}"
  else
    aws ec2 start-instances --instance-ids "${instance_id}" >/dev/null
    aws ec2 wait instance-status-ok --instance-ids "${instance_id}"
  fi
  for _ in {1..60}; do
    status="$(curl --silent --max-time 10 "http://${PRIMARY_EC2_HOST}/api/status" || true)"
    [[ "$(jq -r '.environment // empty' <<< "${status:-{}}")" == "${desired_state}" ]] && break
    sleep 10
  done
  test "$(jq -r .environment <<< "${status}")" = "${desired_state}"
  test "$(jq -r .database <<< "${status}")" = connected
}

cleanup_eks_workload() {
  aws eks update-kubeconfig --name vaultrix-dr-dr-eks --region "${DR_REGION}"
  kubectl get pv -o json | jq -r \
    '.items[] | select(.spec.claimRef.namespace == "notes") | .metadata.name' |
    while read -r pv; do
      kubectl patch pv "${pv}" -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'
    done
  kubectl delete -k kubernetes/overlays/dr --ignore-not-found --wait=true
  helm uninstall aws-load-balancer-controller --namespace kube-system || true
}

cleanup_eks_dns() {
  local zone_id name record batch
  zone_id="$(hosted_zone_id)"
  for name in "${DR_EKS_HOST}." eks-primary.dr.vaultrix.in.; do
    record="$(aws route53 list-resource-record-sets --hosted-zone-id "${zone_id}" \
      --query "ResourceRecordSets[?Name=='${name}' && Type=='CNAME'] | [0]" --output json)"
    [[ "${record}" == null ]] && continue
    batch="$(jq -cn --argjson record "${record}" \
      '{Changes:[{Action:"DELETE",ResourceRecordSet:$record}]}')"
    aws route53 change-resource-record-sets --hosted-zone-id "${zone_id}" \
      --change-batch "${batch}" >/dev/null
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  command="${1:-}"
  shift || true
  case "${command}" in
    capture-eks-snapshot) capture_eks_snapshot ;;
    discover-primary-image) discover_primary_image ;;
    install-load-balancer-controller) install_load_balancer_controller ;;
    create-eks-database-secret) create_eks_database_secret ;;
    deploy-eks) deploy_eks "$@" ;;
    seed-eks) seed_eks "$@" ;;
    capture-ec2-snapshot) capture_ec2_snapshot ;;
    seed-ec2) seed_ec2 ;;
    cutover-eks) cutover_eks "$@" ;;
    validate-dr-ec2) validate_dr_ec2 ;;
    cutover-ec2) cutover_ec2 "$@" ;;
    cleanup-eks-workload) cleanup_eks_workload ;;
    cleanup-eks-dns) cleanup_eks_dns ;;
    *) echo "Unknown DR drill command: ${command}" >&2; exit 2 ;;
  esac
fi
