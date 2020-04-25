#!/bin/bash -e
# Script to create the repositories for a new PRODUCT team.
# * Requires: [UCP_URL, PRODUCT, DTR_URL]to be set as environment variables
# * Requires: Admin bundle certificates in working directory
# * NOTE: Requires DTR to be configured with --enable-client-cert-auth --client-cert-auth-ca "$(cat ca.pem)"
# https://docs.docker.com/ee/enable-client-certificate-authentication/


TEAM=$(echo "$PRODUCT" | awk '{print tolower($0)}')

echo "Setting up DTR Repositories for $TEAM"

token=$(curl -s -d '{"username":"'$UCP_USER'","password":"'$UCP_PASSWORD'"}' https://$UCP_URL/auth/login | jq -r .auth_token) > /dev/null 2>&1
echo $token

echo "Checking for Namespace $TEAM"
code=$(curl -sX GET "https://$UCP_URL/accounts/$TEAM" \
  -H "authorization: Bearer $token" \
  -o /dev/null -w "%{http_code}")

if [ "$code" == "404" ]; then
    echo "Namespace $TEAM does not exist. Must be configured in UCP first."
    exit 1
fi

echo "Create ${TEAM}_dev repository"
code=$(curl -sX GET "https://$DTR_URL/api/v0/repositories/$TEAM/${TEAM}_dev" \
  -o /dev/null -w "%{http_code}")

if [ "$code" == "404" ]; then
    dev_repo=$(curl -sX POST "https://$DTR_URL/api/v0/repositories/$TEAM" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        --cert ./cert.pem --cacert ./ca.pem --key ./key.pem \
        -d "{ 
            \"name\": \"${TEAM}_dev\",
            \"shortDescription\": \"${TEAM} Development\",
            \"longDescription\": \"\", 
            \"enableManifestLists\": false, 
            \"immutableTags\": false,
            \"visibility\": \"public\",
            \"scanOnPush\": false,
            \"tagLimit\": 50 }" )
    
    echo "$dev_repo"

else
    echo "${TEAM}_dev already exists"
fi

echo "Creating ${TEAM}_qa repository"
code=$(curl -sX GET "https://$DTR_URL/api/v0/repositories/$TEAM/${TEAM}_qa" \
  -o /dev/null -w "%{http_code}")

if [ "$code" == "404" ]; then
    repo=$(curl -sX POST "https://$DTR_URL/api/v0/repositories/$TEAM" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        --cert ./cert.pem --cacert ./ca.pem --key ./key.pem  \
        -d "{ 
            \"name\": \"${TEAM}_qa\",
            \"shortDescription\": \"${TEAM} QA\",
            \"longDescription\": \"\", 
            \"enableManifestLists\": false, 
            \"immutableTags\": true,
            \"visibility\": \"public\",
            \"scanOnPush\": false,
            \"tagLimit\": 50 }" )
    
     echo "$repo" 
else
    echo "${TEAM}_qa already exists"
fi

echo "Creating ${TEAM}_staging repository"
code=$(curl -sX GET "https://$DTR_URL/api/v0/repositories/$TEAM/${TEAM}_staging" \
  -o /dev/null -w "%{http_code}")

if [ "$code" == "404" ]; then
    repo=$(curl -sX POST "https://$DTR_URL/api/v0/repositories/$TEAM" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        --cert ./cert.pem --cacert ./ca.pem --key ./key.pem \
        -d "{ 
            \"name\": \"${TEAM}_staging\",
            \"shortDescription\": \"${TEAM} Staging\",
            \"longDescription\": \"\", 
            \"enableManifestLists\": false, 
            \"immutableTags\": true,
            \"visibility\": \"public\",
            \"scanOnPush\": false,
            \"tagLimit\": 50 }" )
    
     echo "$repo" 
else
    echo "${TEAM}_staging already exists"
fi

echo "Creating ${TEAM}_release repository"
code=$(curl -sX GET "https://$DTR_URL/api/v0/repositories/$TEAM/${TEAM}_release" \
  -o /dev/null -w "%{http_code}")

if [ "$code" == "404" ]; then
    repo=$(curl -sX POST "https://$DTR_URL/api/v0/repositories/$TEAM" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        --cert ./cert.pem --cacert ./ca.pem --key ./key.pem \
        -d "{ 
            \"name\": \"${TEAM}_release\",
            \"shortDescription\": \"${TEAM} Release\",
            \"longDescription\": \"\", 
            \"enableManifestLists\": false, 
            \"immutableTags\": true,
            \"visibility\": \"public\",
            \"scanOnPush\": false}" )
    
     echo "$repo" 
else
    echo "${TEAM}_release already exists"
fi
echo "=======================================================\\n\\n\\n"
echo "Repositories created, setting team permissions"

curl -sX PUT "https://$DTR_URL/api/v0/repositories/$TEAM/${TEAM}_dev/teamAccess/dev" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        --cert ./cert.pem --cacert ./ca.pem --key ./key.pem \
        -d '{"accessLevel":"read-write"}' \
        -o /dev/null -w %{http_code}

envs="dev qa staging release"
for val in $envs; do
    echo ""
    echo $val
    curl -sX PUT "https://$DTR_URL/api/v0/repositories/$TEAM/${TEAM}_${val}/teamAccess/lead" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        --cert ./cert.pem --cacert ./ca.pem --key ./key.pem \
        -d '{"accessLevel":"admin"}' \
        -o /dev/null -w %{http_code}
done


