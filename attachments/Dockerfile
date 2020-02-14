FROM docker:18.06

RUN apk update && \
apk -Uuv add python py-pip curl jq && \
pip install awscli && \
apk --purge -v del py-pip && \
rm /var/cache/apk/*

COPY cloudwatch-fargate-metrics /opt/cloudwatch-fargate-metrics

ENTRYPOINT ["/opt/cloudwatch-fargate-metrics/cw-put-pod-metrics.sh"]