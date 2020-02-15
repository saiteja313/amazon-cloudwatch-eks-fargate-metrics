FROM docker:18.06

RUN apk update && \
apk -Uuv add python py-pip curl jq && \
pip install awscli && \
apk --purge -v del py-pip && \
rm /var/cache/apk/* && \
mkdir -p /opt/cloudwatch-fargate-metrics

COPY cw-put-pod-metrics.sh /opt/cloudwatch-fargate-metrics/

ENTRYPOINT ["/opt/cloudwatch-fargate-metrics/cw-put-pod-metrics.sh"]