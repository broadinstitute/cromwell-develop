#!/bin/bash



DOCKER_IMAGES="cromwell cromiam"

if [ ! -z "${DOCKER_TAG}" ]
then
  for image in ${DOCKER_IMAGES}
  do
     echo "Creating ${ENV} tag for ${image}..."
     echo docker pull broadinstitute/${image}:${DOCKER_TAG}
     echo docker tag broadinstitute/${image}:${DOCKER_TAG} broadinstitute/${image}:${ENV}
     echo docker push broadinstitute/${image}:${ENV}
     echo docker rmi broadinstitute/${image}:${ENV} broadinstitute/${image}:${DOCKER_TAG}
  done
  echo "ENV=${ENV}" >> cromwell.properties
  echo "PROJECT=caas" >> cromwell.properties

else
  echo; echo "DOCKER_TAG was not set! Nothing to do!  Exiting!"; echo
  exit 1
fi

