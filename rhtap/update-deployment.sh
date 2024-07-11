#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" 
# summary
source $SCRIPTDIR/common.sh

# Top level parameters     


function patch-gitops() {
	echo "Running  patch-gitops"
	if [ -z "$GITOPS_REPO_URL" ]; then
		echo "GITOPS_REPO_URL not set to a value, deployment will not be updated"
		exit_with_success_result
	fi 

	if [[ -v "$GITOPS_AUTH_PASSWORD" ]]; then
	  gitops_repo_url=${GITOPS_REPO_URL%'.git'}
	  remote_without_protocol=${gitops_repo_url#'https://'} 
	  password=$GITOPS_AUTH_PASSWORD 
	  if [[ -v "$GITOPS_AUTH_USERNAME" ]]; then
	    username=$(cat /gitops-auth-secret/username)
	    echo "https://${username}:${password})@${hostname}" > "${HOME}/.git-credentials"
	    origin_with_auth=https://${username}:${password}@${remote_without_protocol}.git
	  else
	    origin_with_auth=https://${password}@${remote_without_protocol}.git
	  fi
	else
	  echo "git credentials to push into gitops repository ${GITOPS_REPO_URL} is not configured."
	  echo "gitops repository is not updated automatically."
	  echo "You can update gitops repository with the new image: ${PARAM_IMAGE} manually"
	  exit_with_success_result
	fi
	
	git config --global user.email "rhtap@noreplay.com"
	git config --global user.name "gitops-update"
	
	gitops_repo_name=$(basename ${gitops_repo_url})
	rm -rf $gitops_repo_name
	git clone ${GITOPS_REPO_URL}
	cd ${gitops_repo_name}
	
	component_name=$(yq .metadata.name application.yaml)
	deployment_patch_filepath="components/${component_name}/overlays/development/deployment-patch.yaml"
	IMAGE_PATH='.spec.template.spec.containers[0].image'
	old_image=$(yq "${IMAGE_PATH}" "${deployment_patch_filepath}")
	yq e -i "${IMAGE_PATH} |= \"${PARAM_IMAGE}\"" "${deployment_patch_filepath}"
	
	git add .
	git commit -m "Update '${component_name}' component image to: ${PARAM_IMAGE}"
	git remote set-url origin $origin_with_auth
	git push 2> /dev/null || \
	{
	  echo "Failed to push update to gitops repository: ${GITOPS_REPO_URL}"
	  echo 'Do you have correct git credentials configured?'
	  exit_with_fail_result
	}
	echo "Successfully updated development image from ${old_image} to ${PARAM_IMAGE}"
	
}

# Task Steps 
patch-gitops
exit_with_success_result