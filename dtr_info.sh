echo -n "Enter your DTR hostname and press [ENTER]: "
read DTR_HOSTNAME
echo -n "Enter your token and press [ENTER]: "
read TOKEN

repos=$(curl -s -u admin:$TOKEN -X GET "https://$DTR_HOSTNAME/api/v0/repositories?pageSize=0&count=true" -H "accept: application/json" | jq -r -c .repositories)
echo "Repo Count: $(echo $repos | jq 'length')"
repo_list=$(echo "${repos}" | jq -c -r '.[]')
# # Loop through repos to get total tags
tags=0
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)
    tag_headers=$(curl -s -I -u admin:$TOKEN -X GET "https://$DTR_HOSTNAME/api/v0/repositories/${namespace}/${reponame}/tags?pageSize=1&count=true")
    tag_count=$(echo "$tag_headers" | grep 'X-Resource-Count:' | sed 's/[^0-9]*//g')
    tags=$(($tags + $tag_count))
done <<< "$repo_list"

echo "Total Tags: ${tags}"