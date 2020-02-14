
DOCKER_IMAGE_NAME=${1} #Eg: example/docker-image-name
docker build -t ${DOCKER_IMAGE_NAME} .
docker push ${DOCKER_IMAGE_NAME}