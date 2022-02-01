#!/bin/bash
loginpwd="xxxxxxx:xxxxxxx"
ploneurl="https://url/"
boxrootfolderID="xxxxxxxxxx"
client_id="xxxxxxxxxxxxx"
client_secret="xxxxxxxxxxxxxxx"
OIFS="$IFS"
IFS=$'\n'
create_box_folder(){
	token=$(cat token_file)
	#nom_dossier=$(echo $1 | sed 's/%20/-/g')
	nom_dossier=$1
	id_dossier_parent=$2
	id_dossier_created=$(curl -i -s  -X POST "https://api.box.com/2.0/folders" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{"name": "'"${nom_dossier^^}"'","parent": {"id": "'"$id_dossier_parent"'" } }'  | grep -oP ":\"\K\d*" | head -n 1)
	echo $id_dossier_created
}

create_local_folder(){
	if [[ ! -f $1/folderid ]]
	then
	local_folder_name=$2
	mkdir $1
	cat `echo $1 | awk 'BEGIN{FS=OFS="/"}{NF--; print}'`/folderid > $1/parentfolderid
	create_box_folder $local_folder_name $(cat $1/parentfolderid) > $1/folderid
	fi
}

upload_content_box(){
	file_name=$2
	type_ressource=$3
	current_folder=$(echo $1 | awk 'BEGIN{FS=OFS="/"}{NF--; print}')
	case $type_ressource in 
		"contenttype-folder")
			file_path=$1.txt
		;;
		*)
			file_path=$1
		;;
	esac
	case `basename "$file_name"` in
		*.* )
			#cas fichier avec extension
			fileext=""
	        ;;
		* )
       			#cas fichier sans extension
			fileext="."$(file -b $file_path | cut -d" " -f1 | awk '{print tolower($0)}')
       		;;
		esac
	id_dossier=$(cat $current_folder/folderid)
	if [[ ! -f $file_path.id ]]
       	then
	token=$(cat token_file)
	id_file_created=$(curl -i -s --max-time 300  -X POST "https://upload.box.com/api/2.0/files/content" \
     -H "Authorization: Bearer $token" \
     -H "Content-Type: multipart/form-data" \
     -F attributes="{\"name\":\"$file_name$fileext\", \"parent\":{\"id\":\"$id_dossier\"}}" \
     -F file=@$file_path \
     | grep -oP -m 1 "\"file\",\"id\":\"\K\d*")  
	rm $file_path
	[[ $id_file_created ]] && echo $id_file_created  > $file_path.id
	fi	

}
add_comment_box() {
	token=$(cat token_file)
 	comment_content=`cat $1 | sed 's/^[ \t]*//' | sed -z 's/\n/\\\n/g'`
	id_ressource=`cat $2`
	comment_path=$1
	case $3 in 
		"contenttype-folder")
			type_ressource="folder"
			#there is no comment for box folder
		;;
		*)
			type_ressource="file"
			if [[ ! -f $comment_path.id ]]
			then
			[ -z "$comment_content" ] || [ "$comment_content" == '\n' ] || id_comment=$(curl -i -s -X POST "https://api.box.com/2.0/comments" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{ "message": "'"$comment_content"'", "item": {"type": "'"$type_ressource"'","id": '$id_ressource' } }' | grep -oP -m 1 "\"comment\",\"id\":\"\K\d*")
		        [[ $id_comment ]] && echo $id_comment  > $comment_path.id
			fi
		;;
	esac


}
add_description_box() {
	path_description=$1
	description_newline=`cat $path_description | sed 's/^[ \t]*//' | sed -z 's/\n/\\\n/g' `
	description=`echo $description_newline |  sed 's/..$//'`
	id_ressource=`cat $2`
	case $3 in
		"contenttype-folder")
			type_ressource="folder"
		;;
		*)
			type_ressource="file"
		;;
	esac
	[ -z "$description" ] || [ "$description" == '\n' ] || curl -i -s --location --request PUT "https://api.box.com/2.0/folders/$id_ressource" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d '{"description": "'"${description:0:255}"'"}'

}

check_html_content() {
	type_ressource=$4
	path_content=$2
	name_file=$3
        case $type_ressource in
                "contenttype-folder" )
			url_content=$(echo $1 | sed 's/\/folder_contents//')
			path_id=$2/folderid
			curl -k -s --ciphers 'DEFAULT:!DH' -u $loginpwd $url_content | hxselect -c '#parent-fieldname-description' | grep -v -e '^[[:space:]]*$' | sed 's/^ *//g' > $path_content.html
                ;;
                * )
			url_content=$(echo $1/view)
			path_id=$2.id
			curl -k -s --ciphers 'DEFAULT:!DH' -u $loginpwd $url_content | hxselect -c '#content' | hxremove '.documentActions' | hxremove '.contentHistory' | hxremove '.documentFirstHeading' | hxremove '.photoAlbum' | hxremove '.visualNoPrint' | grep -v -e '^[[:space:]]*$' | sed 's/^ *//g' > $path_content.html
                ;;
        esac
	lynx --dump $path_content.html --display_charset=utf-8 -nolist > $path_content.txt
	 #[[ "$type_ressource" == "contenttype-folder" ]] && upload_content_box $path_content $name_file.txt $type_ressource || add_comment_box $path_content.txt $path_id $type_ressource
	 [[ "$type_ressource" == "contenttype-folder" ]]  && add_description_box $path_content.txt $path_id $type_ressource || add_comment_box $path_content.txt $path_id $type_ressource

}
scan_folder() {
	curl -k -s --ciphers 'DEFAULT:!DH' -u $loginpwd $1  | grep 'contenttype-richdocument\|contenttype-file\|contenttype-folder\|contenttype-invoice\|contenttype-document\|contenttype-link\|contenttype-image\|contenttype-news\|contenttype-event'  | grep -v "type_name" 

}

get_content_plone() {
	url_content=$1
	path_content=$2
	type_ressource=$3
        case $type_ressource in
                "contenttype-folder" | "contenttype-file" | "contenttype-image" | "contenttype-invoice")
			curl -k -s --ciphers 'DEFAULT:!DH' -u $loginpwd $url_content -o $path_content
                ;;
                * )
			curl -k -s --ciphers 'DEFAULT:!DH' -u $loginpwd $url_content | hxselect -c '#content' | hxremove '.contentHistory' | hxremove '.documentActions' | grep -v -e '^[[:space:]]*$' | sed 's/^ *//g' >  $path_content.html
		;;
	esac
}
html_to_txt(){
	file_path=$1
	name_file=$2
	lynx --dump $file_path.html --display_charset=utf-8 -nolist > $file_path.txt
	#htmldoc --webpage --charset utf-8 -f $file_path.pdf $file_path.html> /dev/null 2>&1 
	upload_content_box $file_path.txt $name_file.txt
}
get_name_ressource(){
	url=$1
	typeressource=$2
	case $typeressource in
		"contenttype-folder")
			view=""
		;;
		*)
			view="/view"
		;;
	esac
	curl -k -s --ciphers 'DEFAULT:!DH' -u $loginpwd $(echo $url$view | sed 's/\/folder_contents//')  | hxselect -c '.documentFirstHeading' | sed 's/<[^>]*>//g' | grep -v -e '^[[:space:]]*$' | sed 's/^ *//g' | sed 's/ $//g' | sed 's/\//-/g'

}

scan_content() {
for htmline in `scan_folder $1`; do 

	urlressource=$(echo $htmline | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*" | sed 's/\/view$//g')
	typeressource=$(echo $htmline | grep -o "contenttype-[[:alpha:]]*")
	echo $urlressource
	contentpath=$(echo $urlressource | sed "s~${ploneurl}~~g"  | sed "s/\/folder_contents//g")
	case $typeressource in
		"contenttype-folder")
			nameressource=$(get_name_ressource $urlressource $typeressource)
			create_local_folder ./$contentpath $nameressource
			check_html_content $urlressource ./$contentpath $nameressource $typeressource
			scan_content $urlressource
		;;
		"contenttype-file" | "contenttype-image" | "contenttype-invoice")
			nameressource=$(get_name_ressource $urlressource $typeressource)
			get_content_plone $urlressource ./$contentpath $typeressource && upload_content_box ./$contentpath $nameressource
			check_html_content $urlressource ./$contentpath $nameressource $typeressource
		;;
		"contenttype-richdocument" | "contenttype-document" | "contenttype-link" | "contenttype-news" | "contenttype-event")
			nameressource=$(get_name_ressource $urlressource $typeressource)
			get_content_plone $urlressource ./$contentpath $typeressource && html_to_txt ./$contentpath $nameressource &
		;;
	esac
 
done
}


refresh_token_loop() {
	while :; do
	refresh_token=`cat refresh_token_file`
curl -s -i -X POST "https://api.box.com/oauth2/token" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "client_id=$client_id" \
     -d "client_secret=$client_secret" \
     -d "refresh_token=$refresh_token" \
     -d "grant_type=refresh_token" \
     | grep -oP "refresh_token\":\"\K[\d\D]*" | cut -d"\"" -f1 > refresh_token_file
curl -s -i -X POST "https://api.box.com/oauth2/token" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "client_id=$client_id" \
     -d "client_secret=$client_secret" \
     -d "refresh_token=$refresh_token" \
     -d "grant_type=refresh_token" \
     | grep -oP ":\"\K[\d\D]*" | cut -d"\"" -f1 > token_file
	sleep 1200
	done
}


refresh_token_loop &
refresh_token_loop_pid=$!
sleep 3
echo $boxrootfolderID > ./folderid 
scan_content $ploneurl"folder_contents"


kill $refresh_token_loop_pid
