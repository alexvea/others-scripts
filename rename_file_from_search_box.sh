#!/bin/bash
read -p "ID du dossier parent pour la recherche" id_folder
token=`cat token_file`
search_name=""
extension_to_find="error:"
curl -s -X GET "https://api.box.com/2.0/search?query=$search_name&type=file&fields=name&ancestor_folder_ids=$id_folder" -H "Authorization: Bearer $token" | jq -r '.entries[] | "\(.id);\(.name)"' > torename_file

rename_file() {
file_id=$1
name=$2
new_name=${name%.*}.jpeg
curl -X PUT "https://api.box.com/2.0/files/$file_id" \
     -H "Authorization: Bearer $token" \
     -H "Content-Type: application/json" \
    -d '{ "name": "'"${new_name}"'" }' >> renamed_file
}


while read line;do
  id=$(echo $line|awk -F";" '{print $1}')
  name=$(echo $line|awk -F";" '{print $2}')
  #[ ${name##*.} = "$extension_to_find" ] && rename_file $id "$name"
  #[ -z ${name##*.}  ] && echo rename_file $id "$name"
done <torename_file
