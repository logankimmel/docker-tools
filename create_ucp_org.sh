#!/bin/bash
# Script to add a new product team to the Docker Enterprise Platform
# * Requires [UCP_URL, UCP_USER, UCP_PASSWORD, PRODUCT, TEAM_LEAD]to be set as environment variables

# Organization and "view" team with LDAP binding must already exist in UCP

echo "Setting up Docker EE for new product: $PRODUCT, with team lead: $TEAM_LEAD"

token=$(curl -sk -d '{"username":"'$UCP_USER'","password":"'$UCP_PASSWORD'"}' $UCP_URL/auth/login | jq -r .auth_token) > /dev/null 2>&1

echo "Setting up dev and lead teams in the $PRODUCT org"
echo $token
if org_id=$(curl -s -X GET $UCP_URL/accounts/$PRODUCT -H "authorization: Bearer $token" \
    -H 'Content-Type: application/json;charset=utf-8' | jq -e -r .id) ; then
    echo "Organization id: $org_id";
else
    echo "Organization: '$PRODUCT' not found"
    exit 1
fi

if dev_id=$(curl -s -X POST $UCP_URL/accounts/$PRODUCT/teams -H "authorization: Bearer $token" \
    -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-US,en;q=0.5' \
    --compressed -H 'Content-Type: application/json;charset=utf-8' \
    -d '{"name":"dev","description":"Group for Developers"}' | jq -e -r .id); then 
    
    echo "Created dev team: $dev_id"
else
    echo "Error creating dev team"
    exit 1
fi

if lead_id=$(curl -s -X POST $UCP_URL/accounts/$PRODUCT/teams -H "authorization: Bearer $token" \
  -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-US,en;q=0.5' \
  --compressed -H 'Content-Type: application/json;charset=utf-8' \
  -d '{"name":"lead","description":"Group for Team Leads"}' | jq -e -r .id) ; then

    echo "Created lead team: $lead_id"
else
    echo "Error creating lead team"
    exit 1
fi

if view_id=$(curl -s -X GET $UCP_URL/accounts/$PRODUCT/teams/view -H "authorization: Bearer $token" \
  -H 'Content-Type: application/json;charset=utf-8' --compressed | jq -e -r .id) ; then

    echo "View team id: $view_id"
else
    echo "Error retrieving view team id"
    exit 1
fi

echo "Adding $TEAM_LEAD to lead team and setting as org owner"

if user_id=$(curl -s -X GET $UCP_URL/accounts/$org_id/teams/$view_id/members/$TEAM_LEAD -H "authorization: Bearer $token" \
  -H 'Content-Type: application/json;charset=utf-8' --compressed | jq -e -r .member.id) ; then
  
    echo "User '$TEAM_LEAD' id: $user_id"
else
    echo "Error retrieving user '$TEAM_LEAD' id"
    exit 1
fi

if team_member=$(curl -s -X PUT $UCP_URL/accounts/$PRODUCT/teams/lead/members/$TEAM_LEAD \
    -H 'accept: application/json' -H "authorization: Bearer $token" \
    -H 'content-type: application/json' -d '{"isAdmin":true}' | jq -e -r .) ; then

    echo "User '$TEAM_LEAD' added to lead team. '$team_member' "
else
    echo "Error adding user '$TEAM_LEAD' to lead team"
    exit 1
fi

if member=$(curl -s -X PUT $UCP_URL/accounts/$PRODUCT/members/$TEAM_LEAD \
    -H 'accept: application/json' -H "authorization: Bearer $token" \
    -H 'content-type: application/json' -d '{"isAdmin":true}' | jq -e -r .) ; then

    echo "User '$TEAM_LEAD' added as org owner. '$member' "
else
    echo "Error adding '$TEAM_LEAD' as org owner"
    exit 1
fi

echo "Creating K8s ConfigMap with org ID's"
if output=$(kubectl create configmap $PRODUCT-org --from-literal=org=$org_id \
    --from-literal=lead=$lead_id --from-literal=dev=$dev_id \
    --from-literal=view=$view_id -n kube-system) ; then
    echo "$output"
else
    echo "Error Creating ConfigMap"
fi

exit 0

curl -s -X PUT https://ucp.lk.dckr.org/accounts/temporg/members/tdp-view -H 'accept: application/json' \
-d '{"isAdmin":true}' --cacert ./ca.pem --cert ./cert.pem --key ./key.pem -H 'content-type: application/json'