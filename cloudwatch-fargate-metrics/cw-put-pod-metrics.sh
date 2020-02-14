#!/bin/sh

POD_NAME=${1}
AWS_REGION=${2}
POD_NAMESPACE=${3}
K8S_APISERVER_ENDPOINT="https://kubernetes.default"

K8S_API_SERVER_POD_STATUS_ENDPOINT="${K8S_APISERVER_ENDPOINT}/api/v1/namespaces/${POD_NAMESPACE}/pods/${POD_NAME}/status"
K8S_API_SERVER_POD_METRICS_ENDPOINT="${K8S_APISERVER_ENDPOINT}/apis/metrics.k8s.io/v1beta1/namespaces/${POD_NAMESPACE}/pods/${POD_NAME}"

K8S_API_SERVER_BEARER_TOKEN_FILE_PATH="/var/run/secrets/kubernetes.io/serviceaccount/token"
K8S_API_SERVER_CACERT_FILE_PATH="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

function put_cw_metric() {
    CUSTOM_METRIC_REGION=${1}
    CUSTOM_METRIC_NAME=${2}
    CUSTOM_METRIC_NAMESPACE=${3}
    CUSTOM_METRIC_VALUE=${4}
    CUSTOM_METRIC_UNIT=${5} #[ Seconds, Microseconds, Milliseconds, Bytes, Kilobytes, Megabytes, Gigabytes, Terabytes, Bits, Kilobits, Megabits, Gigabits, Terabits, Percent, Count, Bytes/Second, Kilobytes/Second, Megabytes/Second, Gigabytes/Second, Terabytes/Second, Bits/Second, Kilobits/Second, Megabits/Second, Gigabits/Second, Terabits/Second, Count/Second, None ]
    POD_NAME=${POD_NAME}
    CUSTOM_METRIC_TIMESTAMP=$(date +%FT%T)

    aws cloudwatch put-metric-data           \
    --region      ${CUSTOM_METRIC_REGION}    \
    --metric-name ${CUSTOM_METRIC_NAME}      \
    --namespace   ${CUSTOM_METRIC_NAMESPACE} \
    --value       ${CUSTOM_METRIC_VALUE}     \
    --unit        ${CUSTOM_METRIC_UNIT}      \
    --timestamp   ${CUSTOM_METRIC_TIMESTAMP} \
    --dimensions "PodName=${POD_NAME}"
}

echo "$(date) : Getting pod status for Pod : ${POD_NAME} - Namespace : ${POD_NAMESPACE}"
POD_STATUS_JSON=$(curl -s ${K8S_API_SERVER_POD_STATUS_ENDPOINT} --header "Authorization: Bearer $(cat ${K8S_API_SERVER_BEARER_TOKEN_FILE_PATH})" --cacert ${K8S_API_SERVER_CACERT_FILE_PATH})

POD_STATUS=$(echo ${POD_STATUS_JSON} | jq -r '.status.conditions[] | select(.type=="Ready") | if (.reason!=null) then .reason else "ContainersReady" end') #TODO check for conditions!=null
echo "$(date) : POD_STATUS - ${POD_STATUS}"

POD_STATUS_VALUE="null"

if [ "$POD_STATUS" = "ContainersReady" ]; then
  export POD_STATUS_VALUE=0
  echo "$(date) : POD_STATUS_VALUE - ${POD_STATUS_VALUE}"
elif [ "$POD_STATUS" = "ContainersNotReady" ]; then
  export POD_STATUS_VALUE=1
  echo "$(date) : POD_STATUS_VALUE - ${POD_STATUS_VALUE}"
elif [ "$POD_STATUS" = "PodCompleted" ]; then
  export POD_STATUS_VALUE=2
  echo "$(date) : POD_STATUS_VALUE - ${POD_STATUS_VALUE}"
fi

echo "$(date) : POD_STATUS_VALUE = ${POD_STATUS_VALUE}"
echo "$(date) : Sending metric to CloudWatch - ${AWS_REGION} - CUSTOM_METRIC_POD_STATUS - CUSTOM_METRIC_NAMESPACE - ${POD_STATUS_VALUE} - None"
put_cw_metric ${AWS_REGION} CUSTOM_METRIC_POD_STATUS CUSTOM_METRIC_NAMESPACE ${POD_STATUS_VALUE} None

  #POD STATUS IN KUBECTL  ==>  POD STATUS RESON FROM REST API
  #Crashloop    .status.conditions[].select(.type=="Ready").reason=ContainersNotReady
  #completed    .status.conditions[].select(.type=="Ready").reason="PodCompleted"
  #Error        .status.conditions[].select(.type=="Ready").reason=ContainersNotReady
  #Running      .status.conditions[].select(.type=="Ready").reason=null

  # echo $POD_STATUS_JSON | jq .vi 
  # {
  #   "kind": "Pod",
  #   "apiVersion": "v1",
  #   "metadata": {
  #     "name": "cloudwatch-agent-54bcc6596d-kzm2d",
  #     "generateName": "cloudwatch-agent-54bcc6596d-",
  #     "namespace": "amazon-cloudwatch",
  #     "selfLink": "/api/v1/namespaces/amazon-cloudwatch/pods/cloudwatch-agent-54bcc6596d-kzm2d/status",
  #     "uid": "69bdff4a-4e5f-11ea-95ed-021e0f667c28",
  #     "resourceVersion": "16657422",
  #     "creationTimestamp": "2020-02-13T12:50:29Z",
  #     "labels": {
  #       "name": "cloudwatch-agent",
  #       "pod-template-hash": "54bcc6596d"
  #     },
  #     "annotations": {
  #       "kubernetes.io/psp": "eks.privileged"
  #     },
  #     "ownerReferences": [
  #       {
  #         "apiVersion": "apps/v1",
  #         "kind": "ReplicaSet",
  #         "name": "cloudwatch-agent-54bcc6596d",
  #         "uid": "69ddf891-4daf-11ea-95ed-021e0f667c28",
  #         "controller": true,
  #         "blockOwnerDeletion": true
  #       }
  #     ]
  #   },
  #   "spec": {
  #     "volumes": [
  #       {
  #         "name": "cwagentconfig",
  #         "configMap": {
  #           "name": "cwagentconfig",
  #           "defaultMode": 420
  #         }
  #       },
  #       {
  #         "name": "cloudwatch-agent-token-dhr2d",
  #         "secret": {
  #           "secretName": "cloudwatch-agent-token-dhr2d",
  #           "defaultMode": 420
  #         }
  #       }
  #     ],
  #     "containers": [
  #       {
  #         "name": "cloudwatch-agent",
  #         "image": "amazon/cloudwatch-agent:1.230621.0",
  #         "env": [
  #           {
  #             "name": "HOST_IP",
  #             "valueFrom": {
  #               "fieldRef": {
  #                 "apiVersion": "v1",
  #                 "fieldPath": "status.hostIP"
  #               }
  #             }
  #           },
  #           {
  #             "name": "HOST_NAME",
  #             "valueFrom": {
  #               "fieldRef": {
  #                 "apiVersion": "v1",
  #                 "fieldPath": "spec.nodeName"
  #               }
  #             }
  #           },
  #           {
  #             "name": "K8S_NAMESPACE",
  #             "valueFrom": {
  #               "fieldRef": {
  #                 "apiVersion": "v1",
  #                 "fieldPath": "metadata.namespace"
  #               }
  #             }
  #           },
  #           {
  #             "name": "CI_VERSION",
  #             "value": "k8s/1.0.1"
  #           }
  #         ],
  #         "resources": {
  #           "limits": {
  #             "cpu": "200m",
  #             "memory": "200Mi"
  #           },
  #           "requests": {
  #             "cpu": "200m",
  #             "memory": "200Mi"
  #           }
  #         },
  #         "volumeMounts": [
  #           {
  #             "name": "cwagentconfig",
  #             "mountPath": "/etc/cwagentconfig"
  #           },
  #           {
  #             "name": "cloudwatch-agent-token-dhr2d",
  #             "readOnly": true,
  #             "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount"
  #           }
  #         ],
  #         "terminationMessagePath": "/dev/termination-log",
  #         "terminationMessagePolicy": "File",
  #         "imagePullPolicy": "IfNotPresent"
  #       }
  #     ],
  #     "restartPolicy": "Always",
  #     "terminationGracePeriodSeconds": 60,
  #     "dnsPolicy": "ClusterFirst",
  #     "serviceAccountName": "cloudwatch-agent",
  #     "serviceAccount": "cloudwatch-agent",
  #     "nodeName": "ip-192-168-164-46.us-east-2.compute.internal",
  #     "securityContext": {},
  #     "schedulerName": "default-scheduler",
  #     "tolerations": [
  #       {
  #         "key": "node.kubernetes.io/not-ready",
  #         "operator": "Exists",
  #         "effect": "NoExecute",
  #         "tolerationSeconds": 300
  #       },
  #       {
  #         "key": "node.kubernetes.io/unreachable",
  #         "operator": "Exists",
  #         "effect": "NoExecute",
  #         "tolerationSeconds": 300
  #       }
  #     ],
  #     "priority": 0,
  #     "enableServiceLinks": true
  #   },
  #   "status": {
  #     "phase": "Running",
  #     "conditions": [
  #       {
  #         "type": "Initialized",
  #         "status": "True",
  #         "lastProbeTime": null,
  #         "lastTransitionTime": "2020-02-13T12:58:48Z"
  #       },
  #       {
  #         "type": "Ready",
  #         "status": "False",
  #         "lastProbeTime": null,
  #         "lastTransitionTime": "2020-02-13T14:26:30Z",
  #         "reason": "ContainersNotReady",
  #         "message": "containers with unready status: [cloudwatch-agent]"
  #       },
  #       {
  #         "type": "ContainersReady",
  #         "status": "False",
  #         "lastProbeTime": null,
  #         "lastTransitionTime": "2020-02-13T14:26:30Z",
  #         "reason": "ContainersNotReady",
  #         "message": "containers with unready status: [cloudwatch-agent]"
  #       },
  #       {
  #         "type": "PodScheduled",
  #         "status": "True",
  #         "lastProbeTime": null,
  #         "lastTransitionTime": "2020-02-13T12:58:48Z"
  #       }
  #     ],
  #     "hostIP": "192.168.164.46",
  #     "podIP": "192.168.191.207",
  #     "startTime": "2020-02-13T12:58:48Z",
  #     "containerStatuses": [
  #       {
  #         "name": "cloudwatch-agent",
  #         "state": {
  #           "waiting": {
  #             "reason": "CrashLoopBackOff",
  #             "message": "Back-off 5m0s restarting failed container=cloudwatch-agent pod=cloudwatch-agent-54bcc6596d-kzm2d_amazon-cloudwatch(69bdff4a-4e5f-11ea-95ed-021e0f667c28)"
  #           }
  #         },
  #         "lastState": {
  #           "terminated": {
  #             "exitCode": 1,
  #             "reason": "Error",
  #             "startedAt": "2020-02-13T14:25:29Z",
  #             "finishedAt": "2020-02-13T14:26:30Z",
  #             "containerID": "docker://840f3cf4fddae5b42d1a796c1c4251ab860b4bf646c2d96791ee59746e55a9c6"
  #           }
  #         },
  #         "ready": false,
  #         "restartCount": 18,
  #         "image": "amazon/cloudwatch-agent:1.230621.0",
  #         "imageID": "docker-pullable://amazon/cloudwatch-agent@sha256:877106acbc56e747ebe373548c88cd37274f666ca11b5c782211db4c5c7fb64b",
  #         "containerID": "docker://840f3cf4fddae5b42d1a796c1c4251ab860b4bf646c2d96791ee59746e55a9c6"
  #       }
  #     ],
  #     "qosClass": "Guaranteed"
  #   }
  # }

echo "$(date) : Getting Memory utilization for Pod : ${POD_NAME} - Namespace : ${POD_NAMESPACE}"
POD_MEMORY_JSON=$(curl -s ${K8S_API_SERVER_POD_METRICS_ENDPOINT} --header "Authorization: Bearer $(cat ${K8S_API_SERVER_BEARER_TOKEN_FILE_PATH})" --cacert ${K8S_API_SERVER_CACERT_FILE_PATH})

POD_MEMORY_VALUE=$(echo $POD_MEMORY_JSON | jq -r '.containers[].usage.memory| rtrimstr("Ki") | tonumber' | awk '{sum+=$0} END{print sum}')
echo "$(date) : POD_MEMORY_VALUE - ${POD_MEMORY_VALUE}"

echo "$(date) : Sending metric to CloudWatch - ${AWS_REGION} - CUSTOM_METRIC_POD_MEMORY - CUSTOM_METRIC_NAMESPACE - ${POD_MEMORY_VALUE} - Kilobits"
put_cw_metric "${AWS_REGION}" CUSTOM_METRIC_POD_MEMORY CUSTOM_METRIC_NAMESPACE ${POD_MEMORY_VALUE} Kilobits

  # echo $POD_MEMORY_JSON
  # {
  #   "kind": "PodMetrics",
  #   "apiVersion": "metrics.k8s.io/v1beta1",
  #   "metadata": {
  #     "name": "troubleshooting-po2-8649784954-s5kxt",
  #     "namespace": "amazon-cloudwatch",
  #     "selfLink": "/apis/metrics.k8s.io/v1beta1/namespaces/amazon-cloudwatch/pods/troubleshooting-po2-8649784954-s5kxt",
  #     "creationTimestamp": "2020-02-13T14:40:20Z"
  #   },
  #   "timestamp": "2020-02-13T14:39:10Z",
  #   "window": "30s",
  #   "containers": [
  #     {
  #       "name": "t3",
  #       "usage": {
  #         "cpu": "808472n",
  #         "memory": "1396Ki"
  #       }
  #     },
  #     {
  #       "name": "t33",
  #       "usage": {
  #         "cpu": "5712503n",
  #         "memory": "7224Ki"
  #       }
  #     }
  #   ]
  # }

echo "$(date) : Getting CPU utilization for Pod : ${POD_NAME} - Namespace : ${POD_NAMESPACE}"
POD_CPU_JSON=$(curl -s ${K8S_API_SERVER_POD_METRICS_ENDPOINT} --header "Authorization: Bearer $(cat ${K8S_API_SERVER_BEARER_TOKEN_FILE_PATH})" --cacert ${K8S_API_SERVER_CACERT_FILE_PATH})
POD_CPU_VALUE=$(echo ${POD_CPU_JSON} | jq -r '.containers[].usage.cpu| rtrimstr("n") | tonumber' | awk '{sum+=$0} END{print sum}')
echo "$(date) : POD_CPU_VALUE - ${POD_CPU_VALUE}"

echo "$(date) : Sending metric to CloudWatch - ${AWS_REGION} - CUSTOM_METRIC_POD_CPU - CUSTOM_METRIC_NAMESPACE - ${POD_CPU_VALUE} - None"
put_cw_metric ${AWS_REGION} CUSTOM_METRIC_POD_CPU CUSTOM_METRIC_NAMESPACE ${POD_CPU_VALUE} None

  # echo ${POD_CPU_JSON} | jq .
  # {
  #   "kind": "PodMetrics",
  #   "apiVersion": "metrics.k8s.io/v1beta1",
  #   "metadata": {
  #     "name": "troubleshooting-po2-8649784954-s5kxt",
  #     "namespace": "amazon-cloudwatch",
  #     "selfLink": "/apis/metrics.k8s.io/v1beta1/namespaces/amazon-cloudwatch/pods/troubleshooting-po2-8649784954-s5kxt",
  #     "creationTimestamp": "2020-02-13T14:44:54Z"
  #   },
  #   "timestamp": "2020-02-13T14:44:13Z",
  #   "window": "30s",
  #   "containers": [
  #     {
  #       "name": "t3",
  #       "usage": {
  #         "cpu": "910403n",
  #         "memory": "1372Ki"
  #       }
  #     },
  #     {
  #       "name": "t33",
  #       "usage": {
  #         "cpu": "915586n",
  #         "memory": "7460Ki"
  #       }
  #     }
  #   ]
  # }
