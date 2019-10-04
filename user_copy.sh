#!/bin/bash

echo -n "Enter your UCP domain and press [ENTER]: "
read UCP_DOMAIN
echo -n "Enter your UCP Bundle Cert Path and press [ENTER]: "
read DOCKER_CERT_PATH
echo -n "Enter your Original User Subject ID and press [ENTER]: "
read FROM_SUBJECT_ID
echo -n "Enter your New User Subject ID and press [ENTER]: "
read TO_SUBJECT_ID
echo

printf "Setting up organization and team membership\\n\\n\\n"
# Get all orgs the original user belongs to
orgs=$(curl --cert ${DOCKER_CERT_PATH}/cert.pem --key ${DOCKER_CERT_PATH}/key.pem --cacert ${DOCKER_CERT_PATH}/ca.pem -k -X GET "https://$UCP_DOMAIN/accounts/${FROM_SUBJECT_ID}/organizations" | jq -r -c .memberOrgs)
org_list=$(echo "${orgs}" | jq -c -r '.[]')
# Loop through orgs
while IFS= read -r row ; do
    echo "${row}"
    echo "============================================="
    org_id=$(echo "${row}" | jq -r .org.id) 
    org_admin=$(echo "${row}" | jq -r .isAdmin)

    # Add user to org
    echo "Adding user: ${TO_SUBJECT_ID} to org: ${team_id} as admin: ${org_admin}"
    output=$(curl --cert ${DOCKER_CERT_PATH}/cert.pem --key ${DOCKER_CERT_PATH}/key.pem --cacert ${DOCKER_CERT_PATH}/ca.pem -k -H "Content-Type: application/json" -d "{\"isAdmin\":${team_admin}}" -X PUT  "https://$UCP_DOMAIN/accounts/${org_id}/members/${TO_SUBJECT_ID}")
    
    # Get all teams the user belongs to within the org
    teams=$(curl --cert ${DOCKER_CERT_PATH}/cert.pem --key ${DOCKER_CERT_PATH}/key.pem --cacert ${DOCKER_CERT_PATH}/ca.pem -k -X GET "https://$UCP_DOMAIN/accounts/${org_id}/members/${FROM_SUBJECT_ID}/teams" | jq -r -c .memberTeams )
    team_list=$(echo "${teams}" | jq -c -r '.[]')
    if [ -z "$team_list" ]
    then
        continue
    else
        while IFS= read -r team ; do
            echo "${team}"
            echo "++++++++++++++++++++++++++++++++++++++++++"
            team_id=$(echo "${team}" | jq -r .team.id)
            team_admin=$(echo "${team}" | jq -r .isAdmin)

            echo "Adding user: ${TO_SUBJECT_ID} to team: ${team_id} in org: ${org_id} as admin ${team_admin}"
            output=$(curl --cert ${DOCKER_CERT_PATH}/cert.pem --key ${DOCKER_CERT_PATH}/key.pem --cacert ${DOCKER_CERT_PATH}/ca.pem -k -H "Content-Type: application/json" -d "{\"isAdmin\":${team_admin}}" -X PUT  "https://$UCP_DOMAIN/accounts/${org_id}/teams/${team_id}/members/${TO_SUBJECT_ID}")
            echo $output
        done <<< "$team_list"
    fi
done <<< "$org_list"

printf "\n\nSetting up grants\n\n\n"

grants=$(curl --cert ${DOCKER_CERT_PATH}/cert.pem --key ${DOCKER_CERT_PATH}/key.pem --cacert ${DOCKER_CERT_PATH}/ca.pem -k -X GET "https://$UCP_DOMAIN/collectionGrants?subjectID=${FROM_SUBJECT_ID}&subjectType=all&expandUser=false&showPaths=false" | jq -r .grants)

for row in $(echo "${grants}" | jq -c '.[]'); do
    echo $row
    echo "============================================="
    object_id=$(echo ${row} | jq -r .objectID) 
    role_id=$(echo ${row} | jq -r .roleID)
    collection_path=$(echo ${row} | jq -r .collectionPath)
    output=$(curl --cert ${DOCKER_CERT_PATH}/cert.pem --key ${DOCKER_CERT_PATH}/key.pem --cacert ${DOCKER_CERT_PATH}/ca.pem -k -X PUT "https://$UCP_DOMAIN/collectionGrants/${TO_SUBJECT_ID}/${object_id}/${role_id}")
   echo $output
done

exit 0