#!/bin/bash

end_with_error()
{
	echo "ERROR: ${1:-"Unknown Error"} Exiting." 1>&2
	exit 1
}

export TZ=Europe/Berlin
export TIMESTAMP=`(date +'%Y%m%d%H%M')`

# see https://graysonkoonce.com/getting-the-current-branch-name-during-a-pull-request-in-travis-ci/
export BRANCH=$(if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then echo $TRAVIS_BRANCH; else echo $TRAVIS_PULL_REQUEST_BRANCH; fi)
echo "TARVIS_TAG=${TRAVIS_TAG}, TRAVIS_BRANCH=$TRAVIS_BRANCH, PR=$PR, BRANCH=$BRANCH, TIMESTAMP=${TIMESTAMP}"

if [[ -z "${TRAVIS_TAG}" ]] ; then
	TRAVIS_TAG="no_tag"
fi

export release="yubiset_${TRAVIS_TAG}.${TIMESTAMP}"
export release_zip="${release}.zip"
export release_hash="${release}.sha512"
export release_gpg="${release}.sha512.gpg"

echo
echo "Creating ${release_zip}.."
{ zip -rT9 -x".git/*" -x"*.gitignore" -x"*.travis.yml" -x".ci/*" "${release_zip}" * ; } || { end_with_error "Creating zip file failed." ; }
echo "Success!"

echo
echo "Creating ${release_hash}.."
{ sha512sum "${release_zip}" > "${release_hash}" ; } || { end_with_error "Creating hash file failed." ; }
echo Success!

echo
echo "Signing hash file.."
{ gpg --home ./.ci --clearsign -u E5F1E2D4 -o "${release_gpg}" "${release_hash}" ; } || { end_with_error "Creating signature file failed." ; }
echo Success!
