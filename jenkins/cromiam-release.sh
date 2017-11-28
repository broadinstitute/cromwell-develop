#!/bin/bash



DOCKER_IMAGES="cromwell cromiam"

if [ ! -z "${DOCKER_TAG}" ]
then
  for image in ${DOCKER_IMAGES}
  do
     echo "Creating ${ENV} tag for ${image}..."
     docker pull broadinstitute/${image}:${DOCKER_TAG}
     docker tag broadinstitute/${image}:${DOCKER_TAG} broadinstitute/${image}:${ENV}
     docker push broadinstitute/${image}:${ENV}
     docker rmi broadinstitute/${image}:${ENV} broadinstitute/${image}:${DOCKER_TAG}
  done
  echo "ENV=${ENV}" >> cromwell.properties
  echo "PROJECT=caas" >> cromwell.properties
  echo "BRANCH=hf_cleanup" >> cromwell.properties

else
  echo; echo "DOCKER_TAG was not set! Nothing to do!  Exiting!"; echo
  exit 1
fi

